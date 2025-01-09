# frozen_string_literal: true

require 'va_notify/default_callback'

module VANotify
  class StatusUpdate
    attr_reader :notification

    def delegate(notification_callback)
      @notification = VANotify::Notification.find_by(notification_id: notification_callback[:id])

      klass = notification.callback_klass&.constantize || VANotify::DefaultCallback

      raise "#{klass} does not implement #call" klass.respond_to?(:call)

      klass.call(notification)
    rescue => e
      Rails.logger.error(source: notification.source_location, status: notification.status, error_message: e.message)
    end
  end
end
