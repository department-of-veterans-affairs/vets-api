# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'
require 'lighthouse/benefits_claims/intent_to_file/monitor'

module Lighthouse
  class CreateIntentToFileJob
    include Sidekiq::Job

    class CreateIntentToFileError < StandardError; end

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
      form_type, form_start_date, veteran_icn = msg['args']
      itf_log_monitor = BenefitsClaims::IntentToFile::Monitor.new
      itf_type = ITF_FORMS[form_type]
      user_account = UserAccount.find_by(icn: veteran_icn)

      itf_log_monitor.track_create_itf_exhaustion(itf_type, form_start_date, user_account&.id, error)

      # create ITF queue exhaustion entry
      itfqe = IntentToFileQueueExhaustion.create({
                                                   form_type:,
                                                   form_start_date:,
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
    def perform(form_type, form_start_date, veteran_icn)
      init(form_type, veteran_icn)

      @itf_log_monitor.track_create_itf_begun(@itf_type, form_start_date, @user_account&.id)
      @service.create_intent_to_file(@itf_type, '')
      @itf_log_monitor.track_create_itf_success(@itf_type, form_start_date, @user_account&.id)
    rescue => e
      @itf_log_monitor.track_create_itf_failure(@itf_type, form_start_date, @user_account&.id, e)
      raise e
    end

    private

    ##
    # Instantiate instance variables for _this_ job
    #
    def init(form_type, icn)
      @itf_log_monitor = BenefitsClaims::IntentToFile::Monitor.new
      @user_account = UserAccount.find_by(icn:)
      @itf_type = ITF_FORMS[form_type]

      raise CreateIntentToFileError, 'Init failed. No veteran ICN provided' if icn.blank?

      if @user_account.blank?
        raise CreateIntentToFileError,
              'Init failed. User account not found for given veteran ICN'
      end
      raise CreateIntentToFileError, 'Init failed. Invalid ITF type' if @itf_type.blank?

      @service = BenefitsClaims::Service.new(icn)
    end
  end
end
