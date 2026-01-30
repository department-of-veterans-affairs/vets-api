# frozen_string_literal: true

require 'httpclient'

# This client is responsible for downloading the accreditation XLSX file from GCLAWS SSRS
# using NTLM authentication.

module RepresentationManagement
  module GCLAWS
    class XlsxClient
      XLSX_CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'

      # Downloads the accreditation XLSX file from the GCLAWS SSRS server
      #
      # This method uses NTLM authentication to connect to an MS SQL Reporting Server
      # and download an XLSX file. It strictly validates the response content-type
      # to ensure a valid XLSX file is returned.
      #
      # @return [Hash] A hash containing either:
      #   - On success: { success: true, data: <binary_content> }
      #   - On failure: { success: false, error: <error_message>, status: <symbol> }
      #
      # @example Successful download
      #   RepresentationManagement::GCLAWS::XlsxClient.download_accreditation_xlsx
      #   # => { success: true, data: "<binary xlsx content>" }
      #
      # @example Invalid content type
      #   RepresentationManagement::GCLAWS::XlsxClient.download_accreditation_xlsx
      #   # => { success: false, error: "Invalid content type: text/html", status: :unprocessable_entity }
      def self.download_accreditation_xlsx
        configuration = XlsxConfiguration.new
        client = configuration.connection
        url = configuration.url

        response = client.get(url)

        validate_and_process_response(response)
      rescue HTTPClient::TimeoutError => e
        handle_error('timeout', e, :request_timeout, 'GCLAWS XLSX download timed out')
      rescue HTTPClient::BadResponseError => e
        handle_unauthorized_or_bad_response(e)
      rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
        handle_error('connection_failed', e, :service_unavailable, 'GCLAWS XLSX service unavailable')
      rescue => e
        handle_error('unexpected', e, :internal_server_error, "GCLAWS XLSX unexpected error: #{e.message}")
      end

      # Validates the response and returns the binary content if successful
      #
      # @param response [HTTP::Message] The HTTP response from the server
      # @return [Hash] Success or failure hash
      def self.validate_and_process_response(response)
        if response.status == 401
          return handle_error('unauthorized', StandardError.new('Unauthorized'), :unauthorized,
                              'GCLAWS XLSX unauthorized')
        end

        unless response.status == 200
          return handle_error('http_error', StandardError.new("HTTP #{response.status}"),
                              :bad_gateway, "GCLAWS XLSX request failed with status #{response.status}")
        end

        content_type = extract_content_type(response)

        unless content_type == XLSX_CONTENT_TYPE
          return handle_error('invalid_content_type', StandardError.new(content_type), :unprocessable_entity,
                              "Invalid content type: #{content_type}")
        end

        { success: true, data: response.body }
      end

      # Extracts the base content type from the response headers
      #
      # @param response [HTTP::Message] The HTTP response
      # @return [String] The content type without parameters
      def self.extract_content_type(response)
        content_type_header = response.content_type || ''
        content_type_header.split(';').first&.strip || ''
      end

      # Handles unauthorized or other bad response errors from HTTPClient
      #
      # @param exception [HTTPClient::BadResponseError] The exception
      # @return [Hash] Error response hash
      def self.handle_unauthorized_or_bad_response(exception)
        if exception.message.include?('401')
          handle_error('unauthorized', exception, :unauthorized, 'GCLAWS XLSX unauthorized')
        else
          handle_error('bad_response', exception, :bad_gateway, "GCLAWS XLSX bad response: #{exception.message}")
        end
      end

      # Handles errors with logging, Slack notifications, and returns error response
      #
      # @param error_type [String] The type of error
      # @param exception [Exception] The original exception
      # @param status [Symbol] The HTTP status symbol for the response
      # @param error_message [String] The error message
      # @return [Hash] Error response hash
      def self.handle_error(error_type, exception, status, error_message)
        log_error("GCLAWS XLSX #{error_type} error: #{exception.message}")
        notify_slack_error(error_type, exception)

        { success: false, error: error_message, status: }
      end

      # Sends a notification to Slack for critical errors
      #
      # @param error_type [String] The type of error
      # @param exception [Exception] The original exception
      def self.notify_slack_error(error_type, exception)
        message = "🚨 GCLAWS XLSX Download Error Alert!\n" \
                  "Error Type: #{error_type.humanize}\n" \
                  "Message: #{exception.message}\n" \
                  "Time: #{Time.current}\n" \
                  'Action: Manual review recommended'

        log_to_slack_channel(message)
      rescue => e
        log_error("Failed to send Slack notification: #{e.message}")
      end

      # Sends a notification to the Slack channel for XLSX download issues
      #
      # @param message [String] The message to send to Slack
      def self.log_to_slack_channel(message)
        return unless Settings.vsp_environment == 'production'

        slack_client = SlackNotify::Client.new(
          webhook_url: Settings.edu.slack.webhook_url,
          channel: '#benefits-representation-management-notifications',
          username: 'RepresentationManagement::GCLAWS::XlsxClientBot'
        )
        slack_client.notify(message)
      end

      # Logs an error message to the Rails logger
      #
      # @param message [String] The error message to log
      def self.log_error(message)
        Rails.logger.error("RepresentationManagement::GCLAWS::XlsxClient error: #{message}")
      end
    end
  end
end
