# frozen_string_literal: true

module VANotify
  class DefaultCallback
    attr_reader :notification_record, :metadata

    def initialize(notification_record)
      @notification_record = notification_record
      @metadata = notification_record.callback_metadata
    end

    def call
      if metadata.present?
        call_with_metadata
      else
        call_without_metadata
      end
    end

    private

    def call_with_metadata
      notification_type = metadata['notification_type']

      if Flipper.enabled?(:va_notify_metadata_statsd_tags)
        tags = validate_and_normalize_statsd_tags
      else
        statsd_tags = metadata['statsd_tags']
        service = statsd_tags['service']
        function = statsd_tags['function']
        tags = ["service:#{service}", "function:#{function}"]
      end

      case notification_record.status
      when 'delivered'
        delivered(tags) if notification_type == 'error'
      when 'permanent-failure', 'temporary-failure'
        permanent_failure(tags) if notification_type == 'error'
      end
    end

    def call_without_metadata
      case notification_record.status
      when 'delivered'
        delivered_without_metadata
      when 'permanent-failure', 'temporary-failure'
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

    def validate_and_normalize_statsd_tags
      statsd_tags = metadata['statsd_tags']
      required_keys = %w[service function]

      tag_keys, tags = case statsd_tags
                       when Hash
                         keys = statsd_tags.keys
                         tags = statsd_tags.map { |key, value| "#{key}:#{value}" }
                         [keys, tags]
                       when Array
                         keys = statsd_tags.map { |tag| tag.split(':').first }
                         tags = statsd_tags
                         [keys, tags]
                       else
                         raise TypeError, 'Invalid metadata statsd_tags format: must be a Hash or Array'
                       end

      missing_keys = required_keys - tag_keys
      if missing_keys.any?
        raise KeyError,
              "Missing required keys in default_callback metadata statsd_tags: #{missing_keys.join(', ')}"
      end

      tags
    end
  end
end
