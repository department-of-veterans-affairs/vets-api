# frozen_string_literal: true

require 'va_notify/default_callback'

module VANotify
  class CallbackProcessor
    attr_reader :notification, :notification_params

    # @param notification [VANotify::Notification] The notification record
    # @param notification_params [Hash] The callback params to update the notification with
    def initialize(notification, notification_params)
      @notification = notification
      @notification_params = notification_params
    end

    def call
      notification.update(notification_params)

      log_notification_update

      VANotify::DefaultCallback.new(notification).call
      VANotify::CustomCallback.new(notification_params.merge(id: notification.notification_id)).call
    end

    private

    def log_notification_update
      Rails.logger.info("va_notify callback_processor - Updated notification: #{notification.id}", {
                          notification_id: notification.id,
                          source_location: notification.source_location,
                          template_id: notification.template_id,
                          callback_metadata: notification.callback_metadata,
                          status: notification.status,
                          status_reason: notification.status_reason
                        })
    end
  end
end
