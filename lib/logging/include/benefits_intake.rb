# frozen_string_literal: true

module Logging
  module Include
    # Monitor class for tracking claim submission events
    module BenefitsIntake
      # log Sidkiq job started
      #
      # @param claim [SavedClaim]
      # @param lighthouse_service [BenefitsIntake::Service]
      # @param user_account_uuid [UUID]
      def track_submission_begun(claim, lighthouse_service, user_account_uuid)
        submit_event(
          :info,
          "#{message_prefix} submission to LH begun",
          "#{submission_stats_key}.begun",
          claim:,
          user_account_uuid:,
          benefits_intake_uuid: lighthouse_service&.uuid
        )
      end

      # log Sidkiq job Lighthouse submission attempted
      #
      # @param claim [SavedClaim]
      # @param lighthouse_service [BenefitsIntake::Service]
      # @param user_account_uuid [UUID]
      # @param upload [Hash] lighthouse upload data
      def track_submission_attempted(claim, lighthouse_service, user_account_uuid, upload)
        submit_event(
          :info,
          "#{message_prefix} submission to LH attempted",
          "#{submission_stats_key}.attempt",
          claim:,
          user_account_uuid:,
          benefits_intake_uuid: lighthouse_service&.uuid,
          # the fields below will be stripped from the logs in production
          file: upload[:file],
          attachments: upload[:attachments]
        )
      end

      # log Sidkiq job completed
      #
      # @param claim [SavedClaim]
      # @param lighthouse_service [BenefitsIntake::Service]
      # @param user_account_uuid [UUID]
      #
      def track_submission_success(claim, lighthouse_service, user_account_uuid)
        submit_event(
          :info,
          "#{message_prefix} submission to LH succeeded",
          "#{submission_stats_key}.success",
          claim:,
          user_account_uuid:,
          benefits_intake_uuid: lighthouse_service&.uuid
        )
      end

      # log Sidkiq job failed, automatic retry
      #
      # @param claim [SavedClaim]
      # @param lighthouse_service [BenefitsIntake::Service]
      # @param user_account_uuid [UUID]
      # @param e [Error]
      #
      def track_submission_retry(claim, lighthouse_service, user_account_uuid, e)
        submit_event(
          :warn,
          "#{message_prefix} submission to LH failed, retrying",
          "#{submission_stats_key}.failure",
          claim:,
          user_account_uuid:,
          benefits_intake_uuid: lighthouse_service&.uuid,
          error: e&.message,
          call_location: caller_locations.second
        )
      end

      # log Sidkiq job exhaustion, complete failure after all retries
      #
      # @param msg [Hash] sidekiq exhaustion response
      # @option msg [Array<Mixed>] 'args' the arguments supplied to the job
      # @option msg [String] 'error_message' the error message
      # @param claim [SavedClaim]
      def track_submission_exhaustion(msg, claim = nil)
        user_account_uuid = msg['args'].length <= 1 ? nil : msg['args'][1]

        submit_event(
          :error,
          "#{message_prefix} submission to LH exhausted!",
          "#{submission_stats_key}.exhausted",
          claim: claim || msg['args'].first,
          user_account_uuid:,
          error: msg['error_message'],
          call_location: caller_locations.second
        )

        if claim
          claim.send_email(:error) if claim.respond_to?(:send_email)
        else
          log_silent_failure(
            { user_account_uuid:, claim_id: msg['args'].first, error: msg, tags: },
            user_account_uuid,
            call_location: caller_locations.second
          )
        end
      end

      # Tracks the failure to send a Submission in Progress email for a claim.
      #
      # @param claim [SavedClaim]
      # @param lighthouse_service [LighthouseService]
      # @param user_account_uuid [UUID]
      # @param email_type [String] 'submitted' or 'confirmation'
      # @param e [Exception]
      def track_send_email_failure(claim, lighthouse_service, user_account_uuid, email_type, e)
        submit_event(
          :warn,
          "#{message_prefix} send_#{email_type}_email failed",
          "#{submission_stats_key}.send_#{email_type}_failed",
          claim:,
          user_account_uuid:,
          benefits_intake_uuid: lighthouse_service&.uuid,
          error: e&.message
        )
      end

      # log Sidkiq job cleanup error occurred, this can occur post success or failure
      #
      # @param claim [SavedClaim]
      # @param lighthouse_service [BenefitsIntake::Service]
      # @param user_account_uuid [UUID]
      # @param e [Error]
      #
      def track_file_cleanup_error(claim, lighthouse_service, user_account_uuid, e)
        submit_event(
          :error,
          "#{message_prefix} cleanup failed",
          "#{submission_stats_key}.cleanup_failed",
          claim:,
          user_account_uuid:,
          benefits_intake_uuid: lighthouse_service&.uuid,
          error: e&.message
        )
      end

      # log error occurred when setting signature date to claim.created_at
      # Error doesn't prevent successful claim submission (defaults to current date)
      #
      # @param claim [SavedClaim]
      # @param lighthouse_service [BenefitsIntake::Service]
      # @param user_account_uuid [UUID]
      # @param e [Error]
      #
      def track_claim_signature_error(claim, lighthouse_service, user_account_uuid, e)
        submit_event(
          :error,
          "#{message_prefix} claim signature error",
          "#{submission_stats_key}.claim_signature_error",
          claim:,
          user_account_uuid:,
          benefits_intake_uuid: lighthouse_service&.uuid,
          error: e&.message
        )
      end
    end
  end
end
