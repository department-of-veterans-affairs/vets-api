# frozen_string_literal: true

module SimpleFormsApi
  class NotificationCallbacks
    def self.call(notification_record)
      metadata = JSON.parse(notification_record.metadata)
      notification_type = metadata['notification_type']
      form_number = metadata['form_number']

      case notification_record.status
      when 'delivered'
        if notification_type == 'error'
          tags = ['service:veteran-facing-forms', "function: #{form_number} form submission to Lighthouse"]
          StatsD.increment('silent_failure_avoided', tags:)
        end
      when 'permanent-failure'
        if notification_type == 'error'
          tags = ['service:veteran-facing-forms', "function: #{form_number} form submission to Lighthouse"]
          StatsD.increment('silent_failure', tags:)
        end
      end
    end
  end
end
