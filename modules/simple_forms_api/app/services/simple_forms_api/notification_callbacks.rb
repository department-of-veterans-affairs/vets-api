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
        if notification_type == 'error'
          StatsD.increment('silent_failure_avoided', tags:)
          Rails.logger.info('Simple forms api - error email delivered',
                            { notification_record_id: notification_record.id,
                              notification_record_to: notification_record.to,
                              form_number: })
        end
      when 'permanent-failure'
        if notification_type == 'error'
          StatsD.increment('silent_failure', tags:)
          Rails.logger.error('Simple forms api - error email failed to deliver',
                             { notification_record_id: notification_record.id,
                               notification_record_to: notification_record.to,
                               form_number: })
        end
      end
    end
  end
end
