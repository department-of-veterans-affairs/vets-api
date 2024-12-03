# frozen_string_literal: true

require 'va_notify/notification_email/burial'
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

    attr_reader :tags

    def initialize
      super('burial-application')

      @tags = ['form_id:21P-530EZ']
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
        user_account_uuid: current_user&.user_account_uuid,
        message: e&.message,
        tags:
      }
      track_request('error', '21P-530EZ submission not found', CLAIM_STATS_KEY,
                    call_location: caller_locations.first, **additional_context)
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
        user_account_uuid: current_user&.user_account_uuid,
        message: e&.message,
        tags:
      }
      track_request('error', '21P-530EZ fetching submission failed', CLAIM_STATS_KEY,
                    call_location: caller_locations.first, **additional_context)
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
        user_account_uuid: current_user&.user_account_uuid,
        tags:
      }
      track_request('info', '21P-530EZ submission to Sidekiq begun', "#{CLAIM_STATS_KEY}.attempt",
                    call_location: caller_locations.first, **additional_context)
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
        user_account_uuid: current_user&.user_account_uuid,
        in_progress_form_id: in_progress_form&.id,
        errors: claim&.errors&.errors,
        tags:
      }
      track_request('error', '21P-530EZ submission validation error', "#{CLAIM_STATS_KEY}.validation_error",
                    call_location: caller_locations.first, **additional_context)
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
        user_account_uuid: current_user&.user_account_uuid,
        in_progress_form_id: in_progress_form&.id,
        errors: claim&.errors&.errors,
        message: e&.message,
        tags:
      }
      track_request('error', '21P-530EZ submission to Sidekiq failed', "#{CLAIM_STATS_KEY}.failure",
                    call_location: caller_locations.first, **additional_context)
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
        user_account_uuid: current_user&.user_account_uuid,
        in_progress_form_id: in_progress_form&.id,
        errors: claim&.errors&.errors,
        tags:
      }
      track_request('info', '21P-530EZ submission to Sidekiq success', "#{CLAIM_STATS_KEY}.success",
                    call_location: caller_locations.first, **additional_context)
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
        user_account_uuid: current_user&.user_account_uuid,
        in_progress_form_id: in_progress_form&.id,
        errors: claim&.errors&.errors,
        tags:
      }
      track_request('error', '21P-530EZ process attachment error', "#{CLAIM_STATS_KEY}.process_attachment_error",
                    call_location: caller_locations.first, **additional_context)
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
        user_account_uuid: user_account_uuid,
        form_id: claim&.form_id,
        claim_id: msg['args'].first,
        message: msg,
        tags:
      }
      call_location = caller_locations.first

      if claim
        Burials::NotificationEmail.new(claim).deliver(:error)
        log_silent_failure_avoided(additional_context, user_account_uuid, call_location:)
      else
        log_silent_failure(additional_context, user_account_uuid, call_location:)
      end

      track_request('error', 'Lighthouse::SubmitBenefitsIntakeClaim Burial 21P-530EZ submission to LH exhausted!',
                    "#{SUBMISSION_STATS_KEY}.exhausted", call_location:, **additional_context)
    end
  end
end
