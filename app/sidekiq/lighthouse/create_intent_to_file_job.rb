# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'
require 'lighthouse/benefits_claims/intent_to_file/monitor'

module Lighthouse
  class CreateIntentToFileJob
    include Sidekiq::Job

    attr_reader :form, :itf_type

    class MissingICNError < StandardError; end
    class MissingParticipantIDError < StandardError; end
    class FormNotFoundError < StandardError; end
    class InvalidITFTypeError < StandardError; end

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
      in_progress_form_id, veteran_icn = msg['args']
      in_progress_form = InProgressForm.find(in_progress_form_id)
      itf_log_monitor = BenefitsClaims::IntentToFile::Monitor.new
      form_type = in_progress_form&.form_id
      itf_type = ITF_FORMS[form_type]

      itf_log_monitor.track_create_itf_exhaustion(itf_type, in_progress_form, error)

      # create ITF queue exhaustion entry
      exhaustion = IntentToFileQueueExhaustion.create({
                                                        form_type:,
                                                        form_start_date: in_progress_form&.created_at,
                                                        veteran_icn:
                                                      })
      ::Rails.logger.info(
        "IntentToFileQueueExhaustion id: #{exhaustion&.id} entry created", {
          intent_to_file_queue_exhaustion: exhaustion
        }
      )
    end

    ##
    # Create an Intent to File using the Lighthouse ITF endpoint for given in progress form, ICN, and PID
    #
    # On success/failure log and increment the respective Datadog counter
    #
    # @param in_progress_form_id [Integer]
    # @param veteran_icn [String] veteran's ICN
    # @param participant_id [String] veteran's participant ID
    #
    def perform(in_progress_form_id, veteran_icn, participant_id)
      init(in_progress_form_id, veteran_icn, participant_id)

      itf_log_monitor.track_create_itf_begun(itf_type, form&.created_at&.to_s, form&.user_account_id)

      service = BenefitsClaims::Service.new(veteran_icn)
      service.create_intent_to_file(itf_type, '')

      itf_log_monitor.track_create_itf_success(itf_type, form&.created_at&.to_s, form&.user_account_id)
    rescue => e
      triage_rescued_error(e)
    end

    private

    ##
    # Instantiate instance variables for _this_ job
    #
    # @param (see #perform)
    #
    def init(in_progress_form_id, veteran_icn, participant_id)
      raise MissingICNError, 'Init failed. No veteran ICN provided' if veteran_icn.blank?
      raise MissingParticipantIDError, 'Init failed. No veteran participant ID provided' if participant_id.blank?

      @form = InProgressForm.find(in_progress_form_id)
      raise FormNotFoundError, 'Init failed. Form not found for given ID' if form.blank?

      @itf_type = ITF_FORMS[form&.form_id]
      if form.user_account.blank? || form.user_account&.icn != veteran_icn
        raise ActiveRecord::RecordNotFound, 'Init failed. User account not found for given veteran ICN'
      end

      raise InvalidITFTypeError, 'Init failed. Form type not supported for auto ITF' if itf_type.blank?
    end

    ##
    # Track error, prevent retry if will result in known failure, raise again otherwise
    #
    # @param exception [Exception] error thrown within #perform
    #
    def triage_rescued_error(exception)
      if exception.instance_of?(MissingICNError)
        itf_log_monitor.track_missing_user_icn(form, exception)
      elsif exception.instance_of?(MissingParticipantIDError)
        itf_log_monitor.track_missing_user_pid(form, exception)
      elsif exception.instance_of?(InvalidITFTypeError)
        itf_log_monitor.track_invalid_itf_type(form, exception)
      elsif exception.instance_of?(FormNotFoundError)
        itf_log_monitor.track_missing_form(form, exception)
      else
        itf_log_monitor.track_create_itf_failure(itf_type, form&.created_at&.to_s, form&.user_account_id, exception)
        raise exception
      end
    end

    ##
    # retreive a monitor for tracking
    #
    # @return [BenefitsClaims::IntentToFile::Monitor]
    #
    def itf_log_monitor
      @itf_log_monitor ||= BenefitsClaims::IntentToFile::Monitor.new
    end
  end
end
