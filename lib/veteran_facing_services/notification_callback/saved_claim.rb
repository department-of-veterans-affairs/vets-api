# frozen_string_literal: true

require 'veteran_facing_services/notification_callback'
require 'zero_silent_failures/monitor'

module VeteranFacingServices
  module NotificationCallback
    # @see ::VeteranFacingServices::NotificationCallback::Default
    #
    # this parent class is designed to work with VeteranFacingServices::NotificationEmail::SavedClaim
    # and will automatically record `silent_failure**` based on the `email_type` in the metadata
    class SavedClaim < ::VeteranFacingServices::NotificationCallback::Default
      # notification was delivered
      def on_delivered
        update_database if email?

        if email? && email_type.to_s == 'error'
          monitor.log_silent_failure_avoided(zsf_additional_context, email_confirmed: true, call_location:)
        end
      end

      # notification has permanently failed
      def on_permanent_failure
        update_database if email?

        monitor.log_silent_failure(zsf_additional_context, call_location:) if email? && email_type.to_s == 'error'
      end

      # notification has temporarily failed
      def on_temporary_failure
        update_database if email?
      end

      # notification has an unknown status
      def on_other_status
        update_database if email?
      end

      private

      # expected metadata values
      attr_reader :form_id, :saved_claim_id, :email_template_id, :email_type, :service_name

      # find the db record of the claim notification
      def claim_va_notification
        @cvn ||= ClaimVANotification.find_by(form_type: form_id, saved_claim_id:, email_template_id:)
      end

      # update the db record, if one in present
      def update_database
        return unless claim_va_notification

        notification_context = {
          notification_id: notification.notification_id, # uuid
          notification_type: notification.notification_type,
          notification_status: notification.status
        }

        claim_va_notification.update(**notification_context)
      end

      # the monitor to be used
      # @see ZeroSilentFailures::Monitor
      def monitor
        @monitor ||= ZeroSilentFailures::Monitor.new(service_name)
      end

      # additional information to be sent with ZSF tracking
      # @see ::VeteranFacingServices::NotificationCallback::Default#context
      def zsf_additional_context
        context
      end

      # call location to be included with ZSF tracking
      # @see ZeroSilentFailures::Monitor
      # @see Logging::CallLocation
      def call_location
        nil
      end
    end
  end
end
