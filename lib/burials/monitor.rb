# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module Burials
  ##
  # Monitor functions for Rails logging and StatsD
  #
  class Monitor < ::ZeroSilentFailures::Monitor
    # statsd key for api
    CLAIM_STATS_KEY = 'api.burial_claim'

    # statsd key for sidekiq
    SUBMISSION_STATS_KEY = 'worker.lighthouse.submit_benefits_intake_claim'

    def initialize
      super('burial-application')
    end

    ##
    # log GET 404 from controller
    # @see BurialClaimsController
    #
    # @param confirmation_number [UUID] saved_claim guid
    # @param current_user [User]
    # @param e [ActiveRecord::RecordNotFound]
    #
    def track_show404(confirmation_number, current_user, e)
      Rails.logger.error('21P-530EZ submission not found',
                         { confirmation_number:, user_uuid: current_user&.uuid, message: e&.message })
    end

    ##
    # log GET 500 from controller
    # @see BurialClaimsController
    #
    # @param confirmation_number [UUID] saved_claim guid
    # @param current_user [User]
    # @param e [Error]
    #
    def track_show_error(confirmation_number, current_user, e)
      Rails.logger.error('21P-530EZ fetching submission failed',
                         { confirmation_number:, user_uuid: current_user&.uuid, message: e&.message })
    end

    ##
    # log POST processing started
    # @see BurialClaimsController
    #
    # @param claim [SavedClaim::Burial]
    # @param current_user [User]
    #
    def track_create_attempt(claim, current_user)
      StatsD.increment("#{CLAIM_STATS_KEY}.attempt")
      Rails.logger.info('21P-530EZ submission to Sidekiq begun',
                        { confirmation_number: claim&.confirmation_number, user_uuid: current_user&.uuid,
                          statsd: "#{CLAIM_STATS_KEY}.attempt" })
    end

    ##
    # log POST claim save validation error
    # @see BurialClaimsController
    #
    # @param in_progress_form [InProgressForm]
    # @param claim [SavedClaim::Burial]
    # @param current_user [User]
    # @param e [Error]
    #
    def track_create_validation_error(in_progress_form, claim, current_user)
      StatsD.increment("#{CLAIM_STATS_KEY}.validation_error")
      Rails.logger.error('21P-530EZ submission validation error',
                         { confirmation_number: claim&.confirmation_number, user_uuid: current_user&.uuid,
                           in_progress_form_id: in_progress_form&.id, errors: claim&.errors&.errors,
                           statsd: "#{CLAIM_STATS_KEY}.validation_error" })
    end

    ##
    # log POST processing failure
    # @see BurialClaimsController
    #
    # @param in_progress_form [InProgressForm]
    # @param claim [SavedClaim::Burial]
    # @param current_user [User]
    # @param e [Error]
    #
    def track_create_error(in_progress_form, claim, current_user, e = nil)
      StatsD.increment("#{CLAIM_STATS_KEY}.failure")
      Rails.logger.error('21P-530EZ submission to Sidekiq failed',
                         { confirmation_number: claim&.confirmation_number, user_uuid: current_user&.uuid,
                           in_progress_form_id: in_progress_form&.id, errors: claim&.errors&.errors,
                           message: e&.message, statsd: "#{CLAIM_STATS_KEY}.failure" })
    end

    ##
    # log POST processing success
    # @see BurialClaimsController
    #
    # @param in_progress_form [InProgressForm]
    # @param claim [SavedClaim::Burial]
    # @param current_user [User]
    #
    def track_create_success(in_progress_form, claim, current_user)
      StatsD.increment("#{CLAIM_STATS_KEY}.success")
      context = {
        confirmation_number: claim&.confirmation_number,
        user_uuid: current_user&.uuid,
        in_progress_form_id: in_progress_form&.id,
        statsd: "#{CLAIM_STATS_KEY}.success"
      }
      Rails.logger.info('21P-530EZ submission to Sidekiq success', context)
    end

    ##
    # log process_attachments! error
    # @see BurialClaimsController
    #
    # @param in_progress_form [InProgressForm]
    # @param claim [SavedClaim::Burial]
    # @param current_user [User]
    #
    def track_process_attachment_error(in_progress_form, claim, current_user)
      StatsD.increment("#{CLAIM_STATS_KEY}.process_attachment_error")
      context = {
        confirmation_number: claim&.confirmation_number,
        user_uuid: current_user&.uuid,
        in_progress_form_id: in_progress_form&.id,
        errors: claim&.errors&.errors,
        statsd: "#{CLAIM_STATS_KEY}.process_attachment_error"
      }
      Rails.logger.error('21P-530EZ process attachment error', context)
    end

    ##
    # log Sidkiq job exhaustion, complete failure after all retries
    # @see Lighthouse::SubmitBenefitsIntakeClaim
    #
    # @param msg [Hash] sidekiq exhaustion response
    # @param claim [SavedClaim::Burial]
    #
    def track_submission_exhaustion(msg, claim = nil)
      user_account_uuid = msg['args'].length <= 1 ? nil : msg['args'][1]
      additional_context = {
        form_id: claim&.form_id,
        claim_id: msg['args'].first,
        confirmation_number: claim&.confirmation_number,
        message: msg
      }
      log_silent_failure(additional_context, user_account_uuid, call_location: caller_locations.first)

      StatsD.increment("#{SUBMISSION_STATS_KEY}.exhausted")
      Rails.logger.error('Lighthouse::SubmitBenefitsIntakeClaim Burial 21P-530EZ submission to LH exhausted!',
                         user_uuid: user_account_uuid, **additional_context)
    end
  end
end
