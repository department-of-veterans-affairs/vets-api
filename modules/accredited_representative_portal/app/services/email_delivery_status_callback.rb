# frozen_string_literal: true

class EmailDeliveryStatusCallback
  def self.call(notification)
    tags = extract_tags(notification)
    base_metric = 'api.vanotify.notifications'

    case notification.status
    when 'delivered'
      report_success(base_metric, tags)
    when 'permanent-failure', 'temporary-failure'
      report_failure(notification, base_metric, tags)
    else
      report_other(notification, base_metric, tags)
    end
  end

  def self.extract_tags(notification)
    metadata = begin
      notification.callback_metadata.to_h.deep_stringify_keys
    rescue
      {}
    end

    statsd_tags = metadata['statsd_tags'] || {}

    # Ensure both keys and values are strings
    tags = statsd_tags.to_h { |k, v| [k.to_s, v.to_s] }

    # Provide fallback if tags are missing or empty
    tags.presence || {
      'service' => 'va_notify',
      'function' => "callback_status_#{notification.notification_type || 'unknown'}"
    }
  end

  def self.report_success(base_metric, tags)
    StatsD.increment("#{base_metric}.delivered", **tags)
    StatsD.increment('silent_failure_avoided', **tags)
  end

  def self.report_failure(notification, base_metric, tags)
    StatsD.increment("#{base_metric}.#{notification.status}", **tags)
    Rails.logger.error(build_log_payload(notification, tags).to_json)
  end

  def self.report_other(notification, base_metric, tags)
    StatsD.increment("#{base_metric}.other", **tags)
    Rails.logger.warn(build_log_payload(notification, tags).merge(message: 'Unhandled callback status').to_json)
  end

  def self.build_log_payload(notification, tags)
    {
      notification_id: notification.notification_id,
      notification_type: notification.notification_type,
      status: notification.status,
      status_reason: notification.status_reason,
      callback_klass: notification.callback_klass,
      tags:,
      metadata: notification.callback_metadata.to_h,
      source_location: notification.source_location,
      timestamp: Time.current
    }
  end
end
