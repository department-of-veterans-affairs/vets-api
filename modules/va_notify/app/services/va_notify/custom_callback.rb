# frozen_string_literal: true

module VANotify
  class CustomCallback
    attr_reader :notification

    def initialize(notification_callback)
      @notification = VANotify::Notification.find_by(notification_id: notification_callback[:id])
    end

    def call
      return if callback_info_missing?

      klass = constantized_class(notification.callback_klass)
      if klass.respond_to?(:call)
        klass.call(notification)
      else
        begin
          Rails.logger.info(message: 'The callback class does not implement #call')
        ensure
          Rails.logger.info(source: notification.source_location)
        end
      end
    rescue => e
      Rails.logger.info(message: "Rescued #{notification.callback_klass} from VANotify::CustomCallback#call")
      Rails.logger.info(source: notification.source_location, status: notification.status, error_message: e.message)
    end

    private

    def constantized_class(class_name)
      # notification.callback is set by other teams, not user input
      class_name.constantize
    end

    def callback_info_missing?
      if notification.callback_klass.blank?
        Rails.logger.info(message: "VANotify - no callback provided for notification: #{notification.id}")
        true
      else
        false
      end
    end
  end
end
