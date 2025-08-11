# frozen_string_literal: true

# This client is responsible for retrieving accreditation data from the GCLAWS API.

module RepresentationManagement
  module GCLAWS
    class Client
      ALLOWED_TYPES = %w[agents attorneys representatives veteran_service_organizations].freeze
      DEFAULT_PAGE = 1
      DEFAULT_PAGE_SIZE = 100

      # Retrieves accredited entities from the GCLAWS API with error handling
      #
      # This method fetches paginated data for different types of accredited entities
      # (agents, attorneys, representatives, veteran service organizations) from the
      # GCLAWS Accreditation API. It includes comprehensive error handling for common
      # API failure scenarios and returns standardized responses.
      #
      # @param type [String] The entity type to retrieve (must be in ALLOWED_TYPES)
      # @param page [Integer] The page number for pagination (default: 1)
      # @param page_size [Integer] The number of records per page (default: 100)
      # @return [Hash, Faraday::Response] Returns empty hash for invalid types,
      #   successful Faraday response for valid requests, or error response for failures
      #
      # @example Successful request
      #   RepresentationManagement::GCLAWS::Client.get_accredited_entities(type: 'agents')
      #   # => Faraday::Response with body containing agents data
      #
      # @example Invalid entity type
      #   RepresentationManagement::GCLAWS::Client.get_accredited_entities(type: 'invalid')
      #   # => {}
      #
      # @example With pagination
      #   RepresentationManagement::GCLAWS::Client.get_accredited_entities(
      #     type: 'attorneys',
      #     page: 2,
      #     page_size: 50
      #   )
      #
      # @raise [Faraday::UnauthorizedError] Handled internally, returns 401 error response
      # @raise [Faraday::ConnectionFailed] Handled internally, returns 503 error response
      # @raise [Faraday::TimeoutError] Handled internally, returns 408 error response
      def self.get_accredited_entities(type:, page: DEFAULT_PAGE, page_size: DEFAULT_PAGE_SIZE)
        return {} unless ALLOWED_TYPES.include?(type)

        configuration = GCLAWS::Configuration.new(type:, page:, page_size:)

        configuration.connection.get
      rescue Faraday::UnauthorizedError => e
        handle_api_error_and_respond('unauthorized', type, e, :unauthorized, 'GCLAWS Accreditation unauthorized')
      rescue Faraday::ConnectionFailed => e
        handle_api_error_and_respond('connection_failed', type, e, :service_unavailable,
                                     'GCLAWS Accreditation unavailable')
      rescue Faraday::TimeoutError => e
        handle_api_error_and_respond('timeout', type, e, :request_timeout,
                                     'GCLAWS Accreditation request timed out')
      end

      # Handles API errors with logging, Slack notifications, and builds error response
      #
      # @param error_type [String] The type of error (unauthorized, connection_failed, timeout)
      # @param entity_type [String] The entity type being requested
      # @param exception [Exception] The original exception
      # @param status [Symbol] The HTTP status symbol for the response
      # @param error_message [String] The error message for the response
      # @return [Faraday::Response] A standardized error response
      def self.handle_api_error_and_respond(error_type, entity_type, exception, status, error_message)
        # Log and notify about the error
        handle_api_error(error_type, entity_type, exception)

        # Build and return the error response
        build_error_response(status, error_message)
      end

      # Handles API errors with logging and Slack notifications for critical issues
      #
      # @param error_type [String] The type of error (unauthorized, connection_failed, timeout)
      # @param entity_type [String] The entity type being requested
      # @param exception [Exception] The original exception
      def self.handle_api_error(error_type, entity_type, exception)
        error_message = "GCLAWS Accreditation API #{error_type} error for #{entity_type}: #{exception.message}"

        # Log to Rails logger
        log_error(error_message)

        # Send Slack notification for critical errors
        notify_slack_api_error(error_type, entity_type, exception)
      end

      # Sends a notification to Slack for critical API errors
      #
      # @param error_type [String] The type of error
      # @param entity_type [String] The entity type being requested
      # @param exception [Exception] The original exception
      def self.notify_slack_api_error(error_type, entity_type, exception)
        message = "🚨 GCLAWS API Error Alert!\n" \
                  "Error Type: #{error_type.humanize}\n" \
                  "Entity Type: #{entity_type}\n" \
                  "Message: #{exception.message}\n" \
                  "Time: #{Time.current}\n" \
                  'Action: Automatic retry may occur, manual review recommended for persistent issues'

        log_to_slack_api_channel(message)
      rescue => e
        # Don't let Slack notification failures break the main flow
        log_error("Failed to send Slack notification: #{e.message}")
      end

      # Sends a notification to the Slack channel for API issues
      #
      # @param message [String] The message to send to Slack
      def self.log_to_slack_api_channel(message)
        return unless Settings.vsp_environment == 'production'

        slack_client = SlackNotify::Client.new(
          webhook_url: Settings.edu.slack.webhook_url,
          channel: '#benefits-representation-management-notifications',
          username: 'RepresentationManagement::GCLAWS::ClientBot'
        )
        slack_client.notify(message)
      end

      # Builds a standardized error response
      #
      # @param status [Symbol] The HTTP status symbol
      # @param error_message [String] The error message
      # @return [Faraday::Response] A mock response object
      def self.build_error_response(status, error_message)
        Faraday::Response.new(
          status:,
          body: { errors: error_message }.to_json
        )
      end

      # Logs an error message to the Rails logger
      #
      # @param message [String] The error message to log
      def self.log_error(message)
        Rails.logger.error("RepresentationManagement::GCLAWS::Client error: #{message}")
      end
    end
  end
end
