# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'
require 'lighthouse/benefits_claims/intent_to_file/monitor'

module Lighthouse
  class CreateIntentToFileJob
    include Sidekiq::Job

    class MissingICNError < StandardError; end
    class MissingParticipantIDError < StandardError; end
    class InvalidITFTypeError < StandardError; end
    class UserAccountNotFoundError < StandardError; end

    # Only pension form configured to create async ITFs for now
    ITF_FORMS = {
      # '21-526EZ' => 'compensation',
      # '21P-530' => 'survivor',
      # '21P-530V2' => 'survivor',
      '21P-527EZ' => 'pension'
    }.freeze

    # retry for one day
    # exhausted attempts will be logged in intent_to_file_queue_exhaustions table
    sidekiq_options retry: 14, queue: 'low'
    sidekiq_retries_exhausted do |msg, error|
      in_progress_form_id, veteran_icn, participant_id = msg['args']
      in_progress_form = InProgressForm.find(in_progress_form_id)
      itf_log_monitor = BenefitsClaims::IntentToFile::Monitor.new
      form_type = in_progress_form.form_id
      itf_type = ITF_FORMS[form_type]

      itf_log_monitor.track_create_itf_exhaustion(itf_type, in_progress_form, error)

      # create ITF queue exhaustion entry
      itfqe = IntentToFileQueueExhaustion.create({
                                                   form_type:,
                                                   form_start_date: in_progress_form.created_at,
                                                   veteran_icn:
                                                 })
      ::Rails.logger.info(
        "IntentToFileQueueExhaustion id: #{itfqe.id} entry created", {
          intent_to_file_queue_exhaustion: itfqe
        }
      )
    end

    ##
    # Create an Intent to File using the Lighthouse ITF endpoint for given form type and ICN
    #
    # On success do nothing for now
    # Raises CreateIntentToFileError
    #
    # @param [String] form_type
    # @param [ActiveSupport::TimeWithZone] form_start_date
    # @param [String] veteran's ICN
    #
    def perform(in_progress_form_id, veteran_icn, participant_id)
      init(in_progress_form_id, veteran_icn)

      @itf_log_monitor.track_create_itf_begun(@itf_type, @form_start_date, @user_account&.id)
      @service.create_intent_to_file(@itf_type, '')
      @itf_log_monitor.track_create_itf_success(@itf_type, @form_start_date, @user_account&.id)
    rescue MissingICNError, MissingParticipantIDError => e
      if veteran_icn.blank?
        @itf_log_monitor.track_missing_user_icn(@in_progress_form)
      elsif participant_id.blank?
        @itf_log_monitor.track_missing_user_pid(@in_progress_form)
      end
    rescue => e
      @itf_log_monitor.track_create_itf_failure(@itf_type, @form_start_date, @user_account&.id, e)
      raise e
    end

    private

    ##
    # Instantiate instance variables for _this_ job
    #
    def init(in_progress_form_id, icn)
      @in_progress_form = InProgressForm.find(in_progress_form_id)
      @form_type = @in_progress_form.form_id
      @form_start_date = @in_progress_form.created_at
      @itf_log_monitor = BenefitsClaims::IntentToFile::Monitor.new
      @user_account = UserAccount.find_by(icn:)
      @itf_type = ITF_FORMS[@form_type]

      raise MissingICNError, 'Init failed. No veteran ICN provided' if icn.blank?
      raise MissingParticipantIDError, 'Init failed. No veteran participant ID provided' if participant_id.blank?

      if @user_account.blank?
        raise UserAccountNotFoundError,
              'Init failed. User account not found for given veteran ICN'
      end
      raise InvalidITFTypeError, 'Init failed. Invalid ITF type' if @itf_type.blank?

      @service = BenefitsClaims::Service.new(icn)
    end
  end
end
