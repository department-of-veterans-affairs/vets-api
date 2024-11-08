# frozen_string_literal: true

module VANotify
  class DefaultCallback
    def self.call(notification_record)
      metadata = JSON.parse(notification_record.metadata)
      notification_type = metadata['notification_type']
      form_number = metadata['form_number']
      statsd_tags = metadata['statsd_tags']
      service = statsd_tags['service']
      function = statsd_tags['function']
      tags = ["service:#{service}", "function:#{function}"]

      case notification_record.status
      when 'delivered'
        delivered(notification_record, notification_type, tags, form_number)
      when 'permanent-failure'
        permanent_failure(notification_record, notification_type, tags, form_number)
      end
    end

    def self.delivered(notification_record, notification_type, tags, form_number)
      if notification_type == 'error'
        StatsD.increment('silent_failure_avoided', tags:)
        Rails.logger.info('Error notification to user delivered',
                          { notification_record_id: notification_record.id,
                            form_number: })
      end
    end

    def self.permanent_failure(notification_record, notification_type, tags, form_number)
      if notification_type == 'error'
        StatsD.increment('silent_failure', tags:)
        Rails.logger.error('Error notification to user failed to deliver',
                           { notification_record_id: notification_record.id,
                             form_number: })
      end
    end
  end
end
