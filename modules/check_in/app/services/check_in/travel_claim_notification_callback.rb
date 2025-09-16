# frozen_string_literal: true

module CheckIn
  ##
  # Custom callback class for handling VA Notify delivery status updates
  # for travel claim SMS notifications.
  #
  # This class implements the VA Notify custom callback pattern to properly
  # track actual delivery status rather than just API request success.
  #
  # @see https://github.com/department-of-veterans-affairs/vets-api/tree/master/modules/va_notify#custom-callback-handler
  class TravelClaimNotificationCallback
    include TravelClaimNotificationUtilities
    ##
    # Handles VA Notify callback with actual delivery status
    #
    # @param notification [VANotify::Notification] The notification record with status update
    # @return [void]
    def self.call(notification)
      metadata = notification.callback_metadata || {}

      message, log_level = case notification.status
                           when 'delivered'
                             handle_delivered
                           when 'permanent-failure'
                             handle_permanent_failure(metadata)
                           when 'temporary-failure'
                             handle_temporary_failure(metadata)
                           else
                             handle_other_status
                           end

      log_notification(notification, metadata, message, log_level)
    end

    ##
    # Handles successful SMS delivery
    #
    # @return [Array<String, Symbol>] message and log level
    def self.handle_delivered
      StatsD.increment(Constants::STATSD_NOTIFY_DELIVERED)
      ['Travel Claim Notification SMS successfully delivered', :info]
    end

    ##
    # Handles permanent delivery failure
    #
    # @param metadata [Hash] callback metadata containing template_id
    # @return [Array<String, Symbol>] message and log level
    def self.handle_permanent_failure(metadata)
      handle_failure_metrics(metadata)
      ['Travel Claim Notification SMS delivery permanently failed', :error]
    end

    ##
    # Handles temporary delivery failure (end-state)
    #
    # @param metadata [Hash] callback metadata containing template_id
    # @return [Array<String, Symbol>] message and log level
    def self.handle_temporary_failure(metadata)
      handle_failure_metrics(metadata)
      ['Travel Claim Notification SMS delivery temporarily failed (end-state)', :warn]
    end

    ##
    # Handles unknown delivery status
    #
    # @return [Array<String, Symbol>] message and log level
    def self.handle_other_status
      StatsD.increment(Constants::STATSD_NOTIFY_ERROR)
      ['Travel Claim Notification SMS has unknown status', :warn]
    end

    ##
    # Common failure metrics handling for permanent and temporary failures
    #
    # @param metadata [Hash] callback metadata containing template_id
    # @return [void]
    def self.handle_failure_metrics(metadata)
      template_id = metadata['template_id']
      facility_type = determine_facility_type_from_template(template_id)

      increment_silent_failure_metrics(template_id, facility_type)
      StatsD.increment(Constants::STATSD_NOTIFY_ERROR)
    end

    ##
    # Builds common log data structure
    #
    # @param notification [VANotify::Notification] notification object
    # @param metadata [Hash] callback metadata
    # @param message [String] log message
    # @param level [Symbol] log level
    # @return [void]
    def self.log_notification(notification, metadata, message, level)
      template_id = metadata['template_id']
      facility_type = determine_facility_type_from_template(template_id)

      log_data = {
        message:,
        notification_id: notification.notification_id,
        template_id:,
        status: notification.status,
        uuid: metadata['uuid'],
        phone_last_four: extract_phone_last_four(notification.to)
      }

      unless notification.status == 'delivered'
        log_data[:status_reason] = notification.status_reason
        log_data[:facility_type] = facility_type if level == :warn
      end

      Rails.logger.public_send(level, log_data)
    end
  end
end
