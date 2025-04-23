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
        claim_id: claim&.id,
        form_id: claim&.form_id,
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
    def track_create_validation_error(in_progress_form, claim, current_user)
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_account_uuid: current_user&.user_account_uuid,
        in_progress_form_id: in_progress_form&.id,
        claim_id: claim&.id,
        form_id: claim&.form_id,
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
        claim_id: claim&.id,
        form_id: claim&.form_id,
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
        claim_id: claim&.id,
        form_id: claim&.form_id,
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
        claim_id: claim&.id,
        form_id: claim&.form_id,
        errors: claim&.errors&.errors,
        tags:
      }
      track_request('error', '21P-530EZ process attachment error', "#{CLAIM_STATS_KEY}.process_attachment_error",
                    call_location: caller_locations.first, **additional_context)
    end

    # log Sidkiq job started
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param claim [Burials::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_account_uuid [UUID]
    def track_submission_begun(claim, lighthouse_service, user_account_uuid)
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_account_uuid:,
        claim_id: claim&.id,
        form_id: claim&.form_id,
        benefits_intake_uuid: lighthouse_service&.uuid,
        tags:
      }
      track_request('info', 'Burial 21P-530EZ submission to LH begun',
                    "#{SUBMISSION_STATS_KEY}.begun", call_location: caller_locations.first, **additional_context)
    end

    # log Sidkiq job Lighthouse submission attempted
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param claim [Burials::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_account_uuid [UUID]
    # @param upload [Hash] lighthouse upload data
    def track_submission_attempted(claim, lighthouse_service, user_account_uuid, upload)
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_account_uuid:,
        claim_id: claim&.id,
        form_id: claim&.form_id,
        benefits_intake_uuid: lighthouse_service&.uuid,
        file: upload[:file],
        attachments: upload[:attachments],
        tags:
      }
      track_request('info', 'Burial 21P-530EZ submission to LH attempted',
                    "#{SUBMISSION_STATS_KEY}.attempt", call_location: caller_locations.first, **additional_context)
    end

    # log Sidkiq job completed
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param claim [Burials::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_account_uuid [UUID]
    #
    def track_submission_success(claim, lighthouse_service, user_account_uuid)
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_account_uuid:,
        claim_id: claim&.id,
        form_id: claim&.form_id,
        benefits_intake_uuid: lighthouse_service&.uuid,
        tags:
      }
      track_request('info', 'Burial 21P-530EZ submission to LH succeeded',
                    "#{SUBMISSION_STATS_KEY}.success", call_location: caller_locations.first, **additional_context)
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
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_account_uuid:,
        claim_id: claim&.id,
        form_id: claim&.form_id,
        benefits_intake_uuid: lighthouse_service&.uuid,
        message: e&.message,
        tags:
      }
      track_request('warn', 'Burial 21P-530EZ submission to LH failed, retrying',
                    "#{SUBMISSION_STATS_KEY}.failure", call_location: caller_locations.first, **additional_context)
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
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_account_uuid:,
        claim_id: msg['args'].first,
        form_id: claim&.form_id,
        message: msg,
        tags:
      }
      call_location = caller_locations.first

      if claim
        # silent failure tracking in email callback
        Burials::NotificationEmail.new(claim.id).deliver(:error)
      else
        log_silent_failure(additional_context, user_account_uuid, call_location:)
      end

      track_request('error', 'Burial 21P-530EZ submission to LH exhausted!',
                    "#{SUBMISSION_STATS_KEY}.exhausted", call_location:, **additional_context)
    end

    ##
    # Log document processing failures
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param claim [Burials::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_account_uuid [UUID]
    # @param e [Error]
    #
    def track_document_processing_error(claim, lighthouse_service, user_account_uuid, e)
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_account_uuid:,
        claim_id: claim&.id,
        form_id: claim&.form_id,
        benefits_intake_uuid: lighthouse_service&.uuid,
        message: e&.message,
        tags:
      }

      track_request('error', 'Burial 21P-530EZ process document failure',
                    "#{SUBMISSION_STATS_KEY}.process_document_failure", call_location:, **additional_context)
    end

    ##
    # Log metadata generation failures
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param claim [Burials::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_account_uuid [UUID]
    # @param e [Error]
    #
    def track_metadata_generation_error(claim, lighthouse_service, user_account_uuid, e)
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_account_uuid:,
        claim_id: claim&.id,
        form_id: claim&.form_id,
        benefits_intake_uuid: lighthouse_service&.uuid,
        message: e&.message,
        tags:
      }

      track_request('error', 'Burial 21P-530EZ generate metadata failure',
                    "#{SUBMISSION_STATS_KEY}.generate_metadata_failure", call_location:, **additional_context)
    end

    ##
    # Log submission polling failures
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param claim [Burials::SavedClaim]
    # @param lighthouse_service [BenefitsIntake::Service]
    # @param user_account_uuid [UUID]
    # @param e [Error]
    #
    def track_submission_polling_error(claim, lighthouse_service, user_account_uuid, e)
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_account_uuid:,
        claim_id: claim&.id,
        form_id: claim&.form_id,
        benefits_intake_uuid: lighthouse_service&.uuid,
        message: e&.message,
        tags:
      }

      track_request('error', 'Burial 21P-530EZ submission polling failure',
                    "#{SUBMISSION_STATS_KEY}.submission_polling_failure", call_location:, **additional_context)
    end

    ##
    # Tracks the failure to send a Submission in Progress email for a claim.
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param claim [Burials::SavedClaim]
    # @param lighthouse_service [LighthouseService]
    # @param e [Exception]
    #
    def track_send_confirmation_email_failure(claim, lighthouse_service, user_account_uuid, e)
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_account_uuid:,
        claim_id: claim&.id,
        form_id: claim&.form_id,
        benefits_intake_uuid: lighthouse_service&.uuid,
        message: e&.message,
        tags:
      }

      track_request('warn', 'Burial 21P-530EZ send_confirmation_email failed',
                    "#{SUBMISSION_STATS_KEY}.send_confirmation_failed",
                    call_location: caller_locations.first, **additional_context)
    end

    ##
    # Tracks the failure to send a Submission in Progress email for a claim.
    # @see Burials::BenefitsIntake::SubmitClaimJob
    #
    # @param claim [Burials::SavedClaim]
    # @param lighthouse_service [LighthouseService]
    # @param e [Exception]
    #
    def track_send_submitted_email_failure(claim, lighthouse_service, user_account_uuid, e)
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_account_uuid:,
        claim_id: claim&.id,
        form_id: claim&.form_id,
        benefits_intake_uuid: lighthouse_service&.uuid,
        message: e&.message,
        tags:
      }

      track_request('warn', 'Burial 21P-530EZ send_submitted_email failed',
                    "#{SUBMISSION_STATS_KEY}.send_submitted_failed",
                    call_location: caller_locations.first, **additional_context)
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
      additional_context = {
        confirmation_number: claim&.confirmation_number,
        user_account_uuid:,
        claim_id: claim&.id,
        form_id: claim&.form_id,
        benefits_intake_uuid: lighthouse_service&.uuid,
        error: e&.message,
        tags:
      }
      track_request('error', 'Burial 21P-530EZ cleanup failed',
                    "#{SUBMISSION_STATS_KEY}.cleanup_failed",
                    call_location: caller_locations.first, **additional_context)
    end
  end
end
