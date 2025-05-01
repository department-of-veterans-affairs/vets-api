# frozen_string_literal: true

require 'burials/notification_email'
require 'zero_silent_failures/monitor'

module Burials
  ##
  # Monitor functions for Rails logging and StatsD
  #
  class Monitor < ::ZeroSilentFailures::Monitor
    # statsd key for api
    CLAIM_STATS_KEY = 'api.burial_claim'
    # statsd key for sidekiq
    SUBMISSION_STATS_KEY = 'app.burial.submit_benefits_intake_claim'
    # prefix for error message
    MESSAGE_PREFIX = "#{name} #{Burials::FORM_ID}".freeze

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
      submit_event(
        'error',
        "#{MESSAGE_PREFIX} submission not found",
        CLAIM_STATS_KEY,
        user_account_uuid: current_user&.user_account_uuid,
        confirmation_number:,
        message: e&.message
      )
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
      submit_event(
        'error',
        "#{MESSAGE_PREFIX} fetching submission failed",
        CLAIM_STATS_KEY,
        claim: nil,
        user_account_uuid: current_user&.user_account_uuid,
        confirmation_number:,
        message: e&.message
      )
    end

    ##
    # log POST processing started
    # @see BurialClaimsController
    #
    # @param claim [SavedClaim::Burial]
    # @param current_user [User]
    #
    def track_create_attempt(claim, current_user)
      submit_event(
        'info',
        "#{MESSAGE_PREFIX} submission to Sidekiq begun",
        "#{CLAIM_STATS_KEY}.attempt",
        claim:,
        user_account_uuid: current_user&.user_account_uuid
      )
    end

    ##
    # log POST claim save validation error
    # @see BurialClaimsController
    #
    # @param in_progress_form [InProgressForm]
    # @param claim [SavedClaim::Burial]
    # @param current_user [User]
    def track_create_validation_error(in_progress_form, claim, current_user)
      submit_event(
        'error',
        "#{MESSAGE_PREFIX} submission validation error",
        "#{CLAIM_STATS_KEY}.validation_error",
        claim:,
        user_account_uuid: current_user&.user_account_uuid,
        in_progress_form_id: in_progress_form&.id,
        errors: claim&.errors&.errors
      )
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
      submit_event(
        'error',
        "#{MESSAGE_PREFIX} submission to Sidekiq failed",
        "#{CLAIM_STATS_KEY}.failure",
        claim:,
        user_account_uuid: current_user&.user_account_uuid,
        in_progress_form_id: in_progress_form&.id,
        errors: claim&.errors&.errors,
        message: e&.message
      )
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
      submit_event(
        'info',
        "#{MESSAGE_PREFIX} submission to Sidekiq success",
        "#{CLAIM_STATS_KEY}.success",
        claim:,
        user_account_uuid: current_user&.user_account_uuid,
        in_progress_form_id: in_progress_form&.id
      )
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
      submit_event(
        'error',
        "#{MESSAGE_PREFIX} process attachment error",
        "#{CLAIM_STATS_KEY}.process_attachment_error",
        claim:,
        user_account_uuid: current_user&.user_account_uuid,
        in_progress_form_id: in_progress_form&.id,
        errors: claim&.errors&.errors
      )
    end

    # log Sidkiq job started
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param claim [Burials::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_account_uuid [UUID]
    def track_submission_begun(claim, lighthouse_service, user_account_uuid)
      submit_event(
        'info',
        "#{MESSAGE_PREFIX} submission to LH begun",
        "#{SUBMISSION_STATS_KEY}.begun",
        claim:,
        user_account_uuid:,
        benefits_intake_uuid: lighthouse_service&.uuid
      )
    end

    # log Sidkiq job Lighthouse submission attempted
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param claim [Burials::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_account_uuid [UUID]
    # @param upload [Hash] lighthouse upload data
    def track_submission_attempted(claim, lighthouse_service, user_account_uuid, upload)
      submit_event(
        'info',
        "#{MESSAGE_PREFIX} submission to LH attempted",
        "#{SUBMISSION_STATS_KEY}.attempt",
        claim:,
        user_account_uuid:,
        benefits_intake_uuid: lighthouse_service&.uuid,
        file: upload[:file],
        attachments: upload[:attachments]
      )
    end

    # log Sidkiq job completed
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param claim [Burials::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_account_uuid [UUID]
    #
    def track_submission_success(claim, lighthouse_service, user_account_uuid)
      submit_event(
        'info',
        "#{MESSAGE_PREFIX} submission to LH succeeded",
        "#{SUBMISSION_STATS_KEY}.success",
        claim:,
        user_account_uuid:,
        benefits_intake_uuid: lighthouse_service&.uuid
      )
    end

    # log Sidkiq job failed, automatic retry
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param claim [Burials::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_account_uuid [UUID]
    # @param e [Error]
    #
    def track_submission_retry(claim, lighthouse_service, user_account_uuid, e)
      submit_event(
        'warn',
        "#{MESSAGE_PREFIX} submission to LH failed, retrying",
        "#{SUBMISSION_STATS_KEY}.failure",
        claim:,
        user_account_uuid:,
        benefits_intake_uuid: lighthouse_service&.uuid,
        message: e&.message
      )
    end

    ##
    # log Sidkiq job exhaustion, complete failure after all retries
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param msg [Hash] sidekiq exhaustion response
    # @param claim [SavedClaim::Burial]
    #
    def track_submission_exhaustion(msg, claim = nil)
      user_account_uuid = msg['args'].length <= 1 ? nil : msg['args'][1]

      submit_event(
        'error',
        "#{MESSAGE_PREFIX} submission to LH exhausted!",
        "#{SUBMISSION_STATS_KEY}.exhausted",
        claim: claim || msg['args'].first,
        user_account_uuid:,
        message: msg
      )

      handle_exhaustion_notification(claim, user_account_uuid, msg)
    end

    ##
    # Handles notification logic for exhausted submissions
    #
    # @param claim [SavedClaim::Burial]
    # @param user_account_uuid [UUID]
    # @param msg [Hash]
    #
    def handle_exhaustion_notification(claim, user_account_uuid, msg)
      if claim
        # silent failure tracking in email callback
        Burials::NotificationEmail.new(claim.id).deliver(:error)
      else
        log_silent_failure(
          {
            confirmation_number: nil,
            user_account_uuid:,
            claim_id: msg['args'].first,
            form_id: nil,
            message: msg,
            tags:
          },
          user_account_uuid,
          call_location: caller_locations.first
        )
      end
    end

    ##
    # Tracks the failure to send a Submission in Progress email for a claim.
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param claim [Burials::SavedClaim]
    # @param lighthouse_service [LighthouseService]
    # @param user_account_uuid [UUID]
    # @param e [Exception]
    #
    def track_send_confirmation_email_failure(claim, lighthouse_service, user_account_uuid, e)
      submit_event(
        'warn',
        "#{MESSAGE_PREFIX} send_confirmation_email failed",
        "#{SUBMISSION_STATS_KEY}.send_confirmation_failed",
        claim:,
        user_account_uuid:,
        benefits_intake_uuid: lighthouse_service&.uuid,
        message: e&.message
      )
    end

    ##
    # Tracks the failure to send a Submission in Progress email for a claim.
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param claim [Burials::SavedClaim]
    # @param lighthouse_service [LighthouseService]
    # @param user_account_uuid [UUID]
    # @param e [Exception]
    #
    def track_send_submitted_email_failure(claim, lighthouse_service, user_account_uuid, e)
      submit_event(
        'warn',
        "#{MESSAGE_PREFIX} send_submitted_email failed",
        "#{SUBMISSION_STATS_KEY}.send_submitted_failed",
        claim:,
        user_account_uuid:,
        benefits_intake_uuid: lighthouse_service&.uuid,
        message: e&.message
      )
    end

    # log Sidkiq job cleanup error occurred, this can occur post success or failure
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param claim [Burials::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_account_uuid [UUID]
    # @param e [Error]
    #
    def track_file_cleanup_error(claim, lighthouse_service, user_account_uuid, e)
      submit_event(
        'error',
        "#{MESSAGE_PREFIX} cleanup failed",
        "#{SUBMISSION_STATS_KEY}.cleanup_failed",
        claim:,
        user_account_uuid:,
        benefits_intake_uuid: lighthouse_service&.uuid,
        error: e&.message
      )
    end

    private

    ##
    # Submits an event for tracking with standardized payload structure
    #
    # @param level [String] The severity level of the event (e.g., 'error', 'info', 'warn')
    # @param message [String] The message describing the event
    # @param stats_key [String] The key used for stats tracking
    # @param options [Hash] Additional options for the event
    #   @option options [SavedClaim::Burial, Integer, nil] :claim The claim object or claim ID
    #   @option options [String, nil] :user_account_uuid The UUID of the user account
    #   @option options [Hash] :**additional_context Additional context for the event
    #
    def submit_event(level, message, stats_key, options = {})
      claim = options[:claim]
      user_account_uuid = options[:user_account_uuid]
      additional_context = options.except(:claim, :user_account_uuid)

      claim_id = claim.is_a?(Integer) ? claim : claim&.id
      confirmation_number = claim.is_a?(Integer) ? nil : claim&.confirmation_number
      form_id = claim.is_a?(Integer) ? nil : claim&.form_id

      payload = {
        confirmation_number:,
        user_account_uuid:,
        claim_id:,
        form_id:,
        tags:,
        **additional_context
      }

      track_request(level, message, stats_key, call_location: caller_locations.first, **payload)
    end
  end
end
