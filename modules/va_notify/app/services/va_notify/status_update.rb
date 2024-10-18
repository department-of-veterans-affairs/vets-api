# frozen_string_literal: true

module VANotify
  class StatusUpdate
    def delegate(notification_callback)
      delivery_request = VANotify::Notification.find_by(notification_id: notification_callback[:id])

      klass = delivery_request.callback.constantize

      if klass.respond_to?(:call)
        klass.call(delivery_request)
      else
        'error'
      end
    end
  end
end
