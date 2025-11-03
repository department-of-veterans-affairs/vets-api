# frozen_string_literal: true

require 'logging/monitor'

# Library for Veteran Facing Services
module VeteranFacingServices
  # module functions for sending a VaNotify notification email
  module NotificationEmail
    # error indicating failure to send email
    class FailureToSend < StandardError; end

    # default monitor class for notification email
    class Monitor < ::Logging::Monitor
      # statsd metric prefix
      STATSD = 'api.veteran_facing_services.notification_email'

      # allowed parameters
      ALLOWLIST = %w[
        claim_id
        email_type
        email_template_id
        error
        form_id
        saved_claim_id
        service_name
        tags
      ].freeze

      def initialize
        super('vfs-notification-email', allowlist: ALLOWLIST)
      end

      # monitor send successful
      #
      # @param tags [Array<String>] array of tags for StatsD; ["tag_name:tag_value", ...]
      # @param context [Hash] additional information to send with the log
      def send_success(tags:, context: nil)
        message = 'VeteranFacingServices::NotificationEmail send success!'
        metric = "#{STATSD}.send_success"

        track_request(:info, message, metric, call_location:, tags:, **context)
      end

      # monitor send failure
      #
      # @param error [String] the error message to be logged
      # @param tags [Array<String>] array of tags for StatsD; ["tag_name:tag_value", ...]
      # @param context [Hash] additional information to send with the log
      def send_failure(error, tags:, context: nil)
        message = 'VeteranFacingServices::NotificationEmail send failure!'
        metric = "#{STATSD}.send_failure"

        track_request(:error, message, metric, call_location:, tags:, error:, **context)
      end

      # monitor attempting a duplicate notification for the same item
      #
      # @param tags [Array<String>] array of tags for StatsD; ["tag_name:tag_value", ...]
      # @param context [Hash] additional information to send with the log
      def duplicate_attempt(tags:, context: nil)
        message = 'VeteranFacingServices::NotificationEmail duplicate attempt'
        metric = "#{STATSD}.duplicate_attempt"

        track_request(:warn, message, metric, call_location:, tags:, **context)
      end

      private

      # get the location a monitor function was called
      def call_location
        caller_locations.second
      end
    end
  end
end
