# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module BenefitsClaims
  module IntentToFile
    class Monitor < ::Logging::BaseMonitor
      STATSD_KEY_PREFIX = 'worker.lighthouse.intent_to_file'

      def initialize
        super('pension-itf')
      end

      # Tracks and logs an error when a user's ICN (Integration Control Number) is missing during
      # the Intent to File (ITF) process. This method captures relevant information about the
      # error and the associated in-progress form, then sends it to the tracking system.
      #
      # @param form [Object, nil] The in-progress form object, which may be nil. Expected to
      #   respond to `id` and `user_account_id`.
      # @param error [StandardError] The error object containing details about the issue.
      def track_missing_user_icn(form, error)
        payload = {
          error: error.message,
          in_progress_form_id: form&.id,
          user_account_uuid: form&.user_account_id
        }

        track_request(
          :info,
          'V0::IntentToFilesController sync ITF user.icn is blank',
          "#{STATSD_KEY_PREFIX}.user.icn.blank",
          call_location: caller_locations.first,
          **payload
        )
      end

      # Tracks and logs an error when a user's participant ID is missing during the
      # Intent to File (ITF) synchronization process.
      #
      # @param form [Object, nil] The in-progress form object, which may be nil. Expected to
      #   respond to `id` and `user_account_id`.
      # @param error [StandardError] The error object containing details about the issue.
      def track_missing_user_pid(form, error)
        payload = {
          error: error.message,
          in_progress_form_id: form&.id,
          user_account_uuid: form&.user_account_id
        }

        track_request(
          :info,
          'V0::IntentToFilesController sync ITF user.participant_id is blank',
          "#{STATSD_KEY_PREFIX}.user.participant_id.blank",
          call_location: caller_locations.first,
          **payload
        )
      end

      # Tracks a missing form and logs the associated error details.
      #
      # @param form [Object, nil] The in-progress form object, which may be nil. Expected to
      #   respond to `id` and `user_account_id`.
      # @param error [StandardError] The error object containing details about the issue.
      def track_missing_form(form, error)
        payload = {
          error: error.message,
          in_progress_form_id: form&.id,
          user_account_uuid: form&.user_account_id
        }

        track_request(
          :info,
          'V0::IntentToFilesController sync ITF form is missing',
          "#{STATSD_KEY_PREFIX}.form.missing",
          call_location: caller_locations.first,
          **payload
        )
      end

      # Tracks an invalid Intent to File (ITF) type error and logs the relevant details.
      #
      # This method increments a StatsD metric to monitor occurrences of invalid ITF types,
      # constructs a payload with error details and associated form information, and logs
      # the request for further analysis.
      #
      # @param form [Object, nil] The in-progress form object, which may be nil. Expected to
      #   respond to `id` and `user_account_id`.
      # @param error [StandardError] The error object containing details about the invalid ITF type.
      def track_invalid_itf_type(form, error)
        payload = {
          error: error.message,
          in_progress_form_id: form&.id,
          user_account_uuid: form&.user_account_id
        }

        track_request(
          :info,
          'V0::IntentToFilesController sync ITF invalid ITF type',
          "#{STATSD_KEY_PREFIX}.itf.type.invalid",
          call_location: caller_locations.first,
          **payload
        )
      end

      # Tracks the "show" action for an Intent to File (ITF) request.
      #
      # @param form_id [String] The ID of the form associated with the ITF.
      # @param itf_type [String] The type of the ITF (e.g., compensation, pension).
      # @param user_uuid [String] The unique identifier of the user making the request.
      def track_show_itf(form_id, itf_type, user_uuid)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}"]
        payload = { itf_type:, form_id:, user_uuid:, tags: }

        track_request(
          :info,
          'V0::IntentToFilesController ITF show',
          "#{STATSD_KEY_PREFIX}.#{itf_type}.show",
          call_location: caller_locations.first,
          **payload
        )
      end

      # Tracks the "submit" action for an Intent to File (ITF) request.
      #
      # @param form_id [String] The identifier of the form being submitted.
      # @param itf_type [String] The type of ITF being submitted (e.g., compensation, pension).
      # @param user_uuid [String] The unique identifier of the user submitting the ITF.
      def track_submit_itf(form_id, itf_type, user_uuid)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}"]
        payload = { itf_type:, form_id:, user_uuid:, tags: }

        track_request(
          :info,
          'V0::IntentToFilesController ITF submit',
          "#{STATSD_KEY_PREFIX}.#{itf_type}.submit",
          call_location: caller_locations.first,
          **payload
        )
      end

      # Tracks and logs an event when a user's ICN (Integration Control Number) is missing
      # in the Intent to File (ITF) process within the IntentToFilesController.
      #
      # @param method [String] The HTTP method (e.g., "POST", "GET") used in the controller action.
      # @param form_id [String] The identifier of the form being processed.
      # @param itf_type [String] The type of Intent to File being handled.
      # @param user_uuid [String] The UUID of the user associated with the request.
      # @param error [String] The error message or object describing the issue.
      def track_missing_user_icn_itf_controller(method, form_id, itf_type, user_uuid, error)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}", "method:#{method}"]
        payload = { error:, method:, form_id:, itf_type:, user_uuid:, tags: }

        track_request(
          :info,
          'V0::IntentToFilesController ITF user.icn is blank',
          "#{STATSD_KEY_PREFIX}.user.icn.blank",
          call_location: caller_locations.first,
          **payload
        )
      end

      # Tracks and logs an event when a user's participant ID is missing in the
      # IntentToFilesController. This method generates a payload with relevant
      # details and sends it to the tracking system.
      #
      # @param method [String] The name of the method where the issue occurred.
      # @param form_id [String] The ID of the form associated with the ITF.
      # @param itf_type [String] The type of Intent to File (ITF).
      # @param user_uuid [String] The UUID of the user associated with the ITF.
      # @param error [String] The error message or object describing the issue.
      def track_missing_user_pid_itf_controller(method, form_id, itf_type, user_uuid, error)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}", "method:#{method}"]
        payload = { error:, method:, form_id:, itf_type:, user_uuid:, tags: }

        track_request(
          :info,
          'V0::IntentToFilesController ITF user.participant_id is blank',
          "#{STATSD_KEY_PREFIX}.user.participant_id.blank",
          call_location: caller_locations.first,
          **payload
        )
      end

      # Tracks an invalid Intent to File (ITF) type event in the V0::IntentToFilesController.
      #
      # @param method [String] The HTTP method (e.g., "POST", "GET") used in the request.
      # @param form_id [String] The identifier of the form associated with the ITF.
      # @param itf_type [String] The type of the ITF that was deemed invalid.
      # @param user_uuid [String] The unique identifier of the user making the request.
      # @param error [String] The error message or details about the invalid ITF type.
      def track_invalid_itf_type_itf_controller(method, form_id, itf_type, user_uuid, error)
        tags = ["form_id:#{form_id}", "itf_type:#{itf_type}", "method:#{method}"]
        payload = { error:, method:, form_id:, itf_type:, user_uuid:, tags: }

        track_request(
          :info,
          'V0::IntentToFilesController ITF invalid ITF type',
          "#{STATSD_KEY_PREFIX}.itf.type.invalid",
          call_location: caller_locations.first,
          **payload
        )
      end
    end
  end
end
