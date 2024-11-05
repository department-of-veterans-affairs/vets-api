# frozen_string_literal: true

module SimpleFormsApi
  class NotificationCallbacks
    def self.call(notification_record)
      metadata = JSON.parse(notification_record.metadata)
      notification_type = metadata['notification_type']
      form_number = metadata['form_number']
      tags = ['service:veteran-facing-forms', "function: #{form_number} form submission to Lighthouse"]

      case notification_record.status
      when 'delivered'
        StatsD.increment('silent_failure_avoided', tags:) if notification_type == 'error'
      when 'permanent-failure'
        StatsD.increment('silent_failure', tags:) if notification_type == 'error'
      end
    end
  end
end
