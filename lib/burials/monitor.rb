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
      additional_context = {
        confirmation_number:,
        user_uuid: current_user&.uuid,
        message: e&.message
      }
      track_request('error', '21P-530EZ submission not found', CLAIM_STATS_KEY, additional_context, call_location: caller_locations.first)
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
      additional_context = {
        confirmation_number:,
        user_uuid: current_user&.uuid,
        message: e&.message
      }
      track_request('error', '21P-530EZ fetching submission failed', CLAIM_STATS_KEY, additional_context, call_location: caller_locations.first)
    end

    ##
    # log POST processing started
    # @see BurialClaimsController
    #
    # @param claim [SavedClaim::Burial]
    # @param current_user [User]
    #
    def track_create_attempt(claim, current_user)
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_uuid: current_user&.uuid
      }
      track_request('error', '21P-530EZ submission to Sidekiq begun', "#{CLAIM_STATS_KEY}.attempt", additional_context, call_location: caller_locations.first)
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
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_uuid: current_user&.uuid,
        in_progress_form_id: in_progress_form&.id,
        errors: claim&.errors&.errors
      }
      track_request('error', '21P-530EZ submission validation error', "#{CLAIM_STATS_KEY}.validation_error", additional_context, call_location: caller_locations.first)
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
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_uuid: current_user&.uuid,
        in_progress_form_id: in_progress_form&.id,
        errors: claim&.errors&.errors,
        message: e&.message
      }
      track_request('error', '21P-530EZ submission to Sidekiq failed', "#{CLAIM_STATS_KEY}.failure", additional_context, call_location: caller_locations.first)
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
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_uuid: current_user&.uuid,
        in_progress_form_id: in_progress_form&.id,
        errors: claim&.errors&.errors
      }
      track_request('info', '21P-530EZ submission to Sidekiq success', "#{CLAIM_STATS_KEY}.success", additional_context, call_location: caller_locations.first)
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
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_uuid: current_user&.uuid,
        in_progress_form_id: in_progress_form&.id,
        errors: claim&.errors&.errors
      }
      track_request('error', '21P-530EZ process attachment error', "#{CLAIM_STATS_KEY}.process_attachment_error", additional_context, call_location: caller_locations.first)
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
        confirmation_number: claim&.confirmation_number,
        user_uuid: user_account_uuid,
        form_id: claim&.form_id,
        claim_id: msg['args'].first,
        message: msg
      }
      log_silent_failure(additional_context, user_account_uuid, call_location: caller_locations.first)

      track_request('error', 'Lighthouse::SubmitBenefitsIntakeClaim Burial 21P-530EZ submission to LH exhausted!', "#{SUBMISSION_STATS_KEY}.exhausted", additional_context, call_location: caller_locations.first)
    end
  end
end
