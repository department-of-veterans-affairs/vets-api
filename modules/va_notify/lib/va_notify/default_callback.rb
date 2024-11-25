# frozen_string_literal: true

module VANotify
  class DefaultCallback
    attr_reader :notification_record, :metadata

    def initialize(notification_record)
      @notification_record = notification_record
      @metadata = notification_record.callback_metadata
    end

    def call
      if metadata
        call_with_metadata
      else
        call_without_metadata
      end
    end

    private

    def call_with_metadata
      notification_type = metadata['notification_type']
      statsd_tags = metadata['statsd_tags']
      service = statsd_tags['service']
      function = statsd_tags['function']
      tags = ["service:#{service}", "function:#{function}"]

      case notification_record.status
      when 'delivered'
        delivered(tags) if notification_type == 'error'
      when 'permanent-failure'
        permanent_failure(tags) if notification_type == 'error'
      end
    end

    def call_without_metadata
      case notification_record.status
      when 'delivered'
        delivered_without_metadata
      when 'permanent-failure'
        permanent_failure_without_metadata
      end
    end

    def delivered(tags)
      StatsD.increment('silent_failure_avoided', tags:)
      Rails.logger.info('Error notification to user delivered',
                        { notification_record_id: notification_record.id,
                          form_number: metadata['form_number'] })
    end

    def permanent_failure(tags)
      StatsD.increment('silent_failure', tags:)
      Rails.logger.error('Error notification to user failed to deliver',
                         { notification_record_id: notification_record.id,
                           form_number: metadata['form_number'] })
    end

    def delivered_without_metadata
      StatsD.increment('silent_failure_avoided', tags: ['service:none-provided', 'function:none-provided'])
    end

    def permanent_failure_without_metadata
      StatsD.increment('silent_failure', tags: ['service:none-provided', 'function:none-provided'])
    end
  end
end
