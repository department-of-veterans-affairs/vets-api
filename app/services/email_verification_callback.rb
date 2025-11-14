# frozen_string_literal: true

class EmailVerificationCallback
  def self.call(notification)
    tags = extract_tags(notification)
    base_metric = 'api.vanotify.email_verification'

    case notification.status
    when 'delivered'
      StatsD.increment("#{base_metric}.delivered", tags:)
      StatsD.increment('silent_failure_avoided', tags:)
    when 'permanent-failure'
      StatsD.increment("#{base_metric}.permanent_failure", tags:)
      Rails.logger.error('Email verification permanent failure', build_log_payload(notification, tags))
    when 'temporary-failure'
      StatsD.increment("#{base_metric}.temporary_failure", tags:)
      Rails.logger.warn('Email verification temporary failure', build_log_payload(notification, tags))
    else
      StatsD.increment("#{base_metric}.other", tags:)
      Rails.logger.warn('Email verification unhandled status', build_log_payload(notification, tags))
    end
  end

  def self.extract_tags(notification)
    metadata = begin
      notification.callback_metadata.to_h.deep_stringify_keys
    rescue
      {}
    end

    statsd_tags = metadata['statsd_tags'] || {}
    tags = statsd_tags.to_h { |k, v| [k.to_s, v.to_s] }

    tags.presence || {
      'service' => 'vagov-profile-email-verification',
      'function' => 'email_verification_callback'
    }
  end

  def self.build_log_payload(notification, tags)
    {
      notification_id: notification.notification_id,
      notification_type: notification.notification_type,
      status: notification.status,
      status_reason: notification.status_reason,
      tags:,
      timestamp: Time.current
    }
  end
end
