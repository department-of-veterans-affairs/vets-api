# frozen_string_literal: true

module Eps
  # Custom callback class for handling VA Notify email delivery status updates
  # for appointment status notifications.
  #
  # This callback tracks delivery success/failure and provides observability
  # through StatsD metrics and structured logging.
  class AppointmentStatusNotificationCallback
    include VAOS::CommunityCareConstants

    STATSD_KEY = "#{STATSD_PREFIX}.appointment_status_notification".freeze
    STATSD_NOTIFY_SILENT_FAILURE = 'silent_failure'
    STATSD_CC_SILENT_FAILURE_TAGS = [
      COMMUNITY_CARE_SERVICE_TAG,
      'function:appointment_status_notification'
    ].freeze
    FAILURE_STATUSES = %w[permanent-failure temporary-failure technical-failure].freeze
    FAILURE_TYPE_MAP = {
      'permanent-failure' => 'permanent',
      'temporary-failure' => 'temporary',
      'technical-failure' => 'technical'
    }.freeze

    # Main callback entry point called by VA Notify
    #
    # @param notification [VANotify::Notification] The notification object from VA Notify
    # @return [void]
    def self.call(notification)
      return handle_missing_notification if notification.nil?

      metadata = extract_metadata(notification)
      base_data = build_base_data(notification, metadata)

      handle_notification_status(notification, base_data)
    rescue => e
      handle_callback_error(e, notification)
    end

    # Extract and validate callback metadata
    #
    # @param notification [VANotify::Notification] The notification object
    # @return [Hash] The callback metadata hash
    def self.extract_metadata(notification)
      metadata = notification.callback_metadata || {}

      # Log warning if metadata is missing or incomplete
      if metadata.empty? || metadata['user_uuid'].blank? || metadata['appointment_id_last4'].blank?
        Rails.logger.warn(
          "#{CC_APPOINTMENTS}: Eps::AppointmentNotificationCallback received missing or incomplete metadata",
          notification_id: notification.notification_id,
          metadata_present: !metadata.empty?,
          user_uuid_present: metadata['user_uuid'].present?,
          appointment_id_present: metadata['appointment_id_last4'].present?,
          status: notification.status
        )
        StatsD.increment("#{STATSD_KEY}.missing_metadata", tags: ['service:community_care_appointments'])
      end

      metadata
    end

    # Build base data structure for logging and metrics
    #
    # @param notification [VANotify::Notification] The notification object
    # @param metadata [Hash] The callback metadata
    # @return [Hash] Base data structure
    def self.build_base_data(notification, metadata)
      {
        notification_id: notification.notification_id,
        user_uuid: metadata['user_uuid'] || 'missing',
        appointment_id_last4: metadata['appointment_id_last4'] || 'missing',
        status: notification.status,
        created_at: notification.created_at,
        sent_at: notification.sent_at,
        completed_at: notification.completed_at
      }
    end

    # Handle different notification statuses
    #
    # @param notification [VANotify::Notification] The notification object
    # @param base_data [Hash] Base data for logging and metrics
    # @return [void]
    def self.handle_notification_status(notification, base_data)
      status = notification.status&.downcase

      case status.downcase
      when 'delivered'
        StatsD.increment("#{STATSD_KEY}.success", tags: [COMMUNITY_CARE_SERVICE_TAG])
      when *FAILURE_STATUSES
        handle_failure(notification, base_data)
      else
        handle_unknown_status(notification, base_data)
      end
    end

    # Handle delivery failures
    #
    # @param notification [VANotify::Notification] The notification object
    # @param base_data [Hash] Base data for logging and metrics
    # @return [void]
    def self.handle_failure(notification, base_data)
      StatsD.increment("#{STATSD_KEY}.failure", tags: [COMMUNITY_CARE_SERVICE_TAG])
      StatsD.increment(STATSD_NOTIFY_SILENT_FAILURE, tags: STATSD_CC_SILENT_FAILURE_TAGS)

      failure_type = FAILURE_TYPE_MAP[notification.status&.downcase] || 'unknown'
      failure_data = base_data.merge(
        status_reason: notification.status_reason,
        failure_type:
      )

      Rails.logger.error(
        "#{CC_APPOINTMENTS}: Eps::AppointmentNotificationCallback delivery failed",
        failure_data
      )
    end

    # Handle unknown or unexpected statuses
    #
    # @param notification [VANotify::Notification] The notification object
    # @param base_data [Hash] Base data for logging and metrics
    # @return [void]
    def self.handle_unknown_status(notification, base_data)
      StatsD.increment("#{STATSD_KEY}.unknown_status", tags: [COMMUNITY_CARE_SERVICE_TAG])

      unknown_data = base_data.merge(
        status_reason: notification.status_reason
      )

      Rails.logger.warn(
        "#{CC_APPOINTMENTS}: Eps::AppointmentNotificationCallback received unknown status",
        unknown_data
      )
    end

    # Handle missing notification object
    #
    # @return [void]
    def self.handle_missing_notification
      StatsD.increment("#{STATSD_KEY}.missing_notification")
      Rails.logger.error(
        'Community Care Appointments: Eps::AppointmentNotificationCallback called with nil notification object'
      )
    end

    # Handle callback processing errors
    #
    # @param error [Exception] The error that occurred
    # @param notification [VANotify::Notification, nil] The notification object if available
    # @return [void]
    def self.handle_callback_error(error, notification = nil)
      StatsD.increment("#{STATSD_KEY}.callback_error")

      error_data = {
        error_class: error.class.name,
        error_message: error.message,
        notification_id: notification&.notification_id,
        user_uuid: notification&.callback_metadata&.dig('user_uuid') || 'missing',
        appointment_id_last4: notification&.callback_metadata&.dig('appointment_id_last4') || 'missing'
      }

      Rails.logger.error(
        "#{CC_APPOINTMENTS}: Eps::AppointmentNotificationCallback error processing callback",
        error_data
      )
    end

    # Build StatsD tags for metrics
    #
    # @return [Array<String>] Array of StatsD tags
    def self.build_statsd_tags
      [COMMUNITY_CARE_SERVICE_TAG]
    end
  end
end
