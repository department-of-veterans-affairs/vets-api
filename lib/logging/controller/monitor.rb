# frozen_string_literal: true

require 'logging/attachment_sanitizer'
module Logging
  module Controller
    # Monitor class for tracking claim controller events
    module Monitor
      include Logging::AttachmentSanitizer
      ##
      # log GET 404 from controller
      # @see ClaimsController
      #
      # @param confirmation_number [UUID] saved_claim guid
      # @param current_user [User]
      # @param e [ActiveRecord::RecordNotFound]
      #
      def track_show404(confirmation_number, current_user, e)
        submit_event(
          :error,
          "#{message_prefix} submission not found",
          claim_stats_key,
          user_account_uuid: current_user&.user_account_uuid,
          confirmation_number:,
          message: e&.message
        )
      end

      ##
      # log GET 500 from controller
      # @see ClaimsController
      #
      # @param confirmation_number [UUID] saved_claim guid
      # @param current_user [User]
      # @param e [Error]
      #
      def track_show_error(confirmation_number, current_user, e)
        submit_event(
          :error,
          "#{message_prefix} fetching submission failed",
          claim_stats_key,
          claim: nil,
          user_account_uuid: current_user&.user_account_uuid,
          confirmation_number:,
          message: e&.message
        )
      end

      ##
      # log POST processing started
      # @see ClaimsController
      #
      # @param claim [SavedClaim]
      # @param current_user [User]
      #
      def track_create_attempt(claim, current_user)
        submit_event(
          :info,
          "#{message_prefix} submission to Sidekiq begun",
          "#{claim_stats_key}.attempt",
          claim:,
          user_account_uuid: current_user&.user_account_uuid
        )
      end

      ##
      # log POST claim save validation error
      # @see ClaimsController
      #
      # @param in_progress_form [InProgressForm]
      # @param claim [SavedClaim]
      # @param current_user [User]
      def track_create_validation_error(in_progress_form, claim, current_user)
        submit_event(
          :error,
          "#{message_prefix} submission validation error",
          "#{claim_stats_key}.validation_error",
          claim:,
          user_account_uuid: current_user&.user_account_uuid,
          in_progress_form_id: in_progress_form&.id,
          errors: claim&.errors&.errors
        )
      end

      ##
      # log POST processing failure
      # @see ClaimsController
      #
      # @param in_progress_form [InProgressForm]
      # @param claim [SavedClaim]
      # @param current_user [User]
      # @param e [Error]
      #
      def track_create_error(in_progress_form, claim, current_user, e = nil)
        submit_event(
          :error,
          "#{message_prefix} submission to Sidekiq failed",
          "#{claim_stats_key}.failure",
          claim:,
          user_account_uuid: current_user&.user_account_uuid,
          in_progress_form_id: in_progress_form&.id,
          errors: claim&.errors&.errors,
          message: e&.message
        )
      end

      ##
      # log POST processing success
      # @see ClaimsController
      #
      # @param in_progress_form [InProgressForm]
      # @param claim [SavedClaim]
      # @param current_user [User]
      #
      def track_create_success(in_progress_form, claim, current_user)
        submit_event(
          :info,
          "#{message_prefix} submission to Sidekiq success",
          "#{claim_stats_key}.success",
          claim:,
          user_account_uuid: current_user&.user_account_uuid,
          in_progress_form_id: in_progress_form&.id
        )
      end

      ##
      # log process_attachments! error
      # @see ClaimsController
      #
      # @param in_progress_form [InProgressForm]
      # @param claim [SavedClaim]
      # @param current_user [User]
      #
      def track_process_attachment_error(in_progress_form, claim, current_user)
        submit_event(
          :error,
          "#{message_prefix} process attachment error",
          "#{claim_stats_key}.process_attachment_error",
          claim:,
          user_account_uuid: current_user&.user_account_uuid,
          in_progress_form_id: in_progress_form&.id,
          errors: claim&.errors&.errors
        )

        handle_bad_attachments(claim, in_progress_form) if Flipper.enabled?(:monitor_process_attachments_sanitizer)
      end

      ##
      # Provides a default mapping from claim attachment keys (as used in claim models)
      # to in-progress form keys (as used in InProgressForm#form_data).
      #
      # This method is intended to be overridden in subclasses or including modules
      # (such as Burials::Monitor) where the mapping between claim attachment keys
      # and in-progress form keys differs from the default.
      #
      # By default, it returns an empty hash, meaning no mapping is applied.
      # This allows the attachment sanitizer and related utilities to safely call
      # `attachment_key_map` without raising errors, and enables flexible extension
      # for claim types with custom key mappings.
      #
      # @return [Hash] mapping of claim attachment keys to in-progress form keys
      def attachment_key_map
        {}
      end
    end
  end
end
