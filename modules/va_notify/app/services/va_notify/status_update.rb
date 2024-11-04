# frozen_string_literal: true

module VANotify
  class StatusUpdate
    attr_reader :notification

    def delegate(notification_callback)
      @notification = VANotify::Notification.find_by(notification_id: notification_callback[:id])

      return if callback_info_missing?

      klass = constantized_class(notification.callback)
      if klass.respond_to?(:call)
        begin
          klass.call(notification)
        rescue => e
          Rails.logger.info(e.message)
        end
      else
        begin
          Rails.logger.info(message: 'The callback class does not implement #call')
        ensure
          Rails.logger.info(source: notification.source_location)
        end
      end
    rescue => e
      Rails.logger.info(source: notification.source_location, status: notification.status, error_message: e.message)
    end

    private

    def constantized_class(class_name)
      # notification.callback is set by other teams, not user input
      class_name.constantize
    end

    def callback_info_missing?
      if notification.callback.blank?
        Rails.logger.info(message: "VANotify - no callback provided for notification: #{notification.id}")
        true
      else
        false
      end
    end
  end
end
