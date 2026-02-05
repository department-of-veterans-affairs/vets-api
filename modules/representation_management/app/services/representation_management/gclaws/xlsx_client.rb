# frozen_string_literal: true

require 'open3'
require 'tempfile'

# This client is responsible for downloading the accreditation XLSX file from GCLAWS SSRS
# using NTLM authentication via system curl command.

module RepresentationManagement
  module GCLAWS
    class XlsxClient
      XLSX_CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'

      # Downloads the accreditation XLSX file from the GCLAWS SSRS server
      #
      # This method uses NTLM authentication (via curl --ntlm) to connect to an MS SQL Reporting Server
      # and download an XLSX file. It strictly validates the response content-type
      # to ensure a valid XLSX file is returned.
      #
      # The method expects a block and yields a result hash containing either:
      #   - On success: { success: true, file_path: <path_to_tempfile> }
      #   - On failure: { success: false, error: <error_message>, status: <symbol> }
      #
      # The downloaded file is stored in a tempfile that is automatically cleaned up
      # after the block completes (even if an exception occurs).
      #
      # @yield [Hash] Result hash with success/error information
      # @return [void]
      #
      # @example Successful download
      #   RepresentationManagement::GCLAWS::XlsxClient.download_accreditation_xlsx do |result|
      #     if result[:success]
      #       data = File.read(result[:file_path])
      #       # process XLSX data
      #     else
      #       Rails.logger.error("Download failed: #{result[:error]}")
      #     end
      #   end
      #   # Tempfile automatically deleted here
      def self.download_accreditation_xlsx
        raise ArgumentError, 'Block required' unless block_given?

        config = XlsxConfiguration.new
        output_file = nil

        begin
          output_file = Tempfile.new(['gclaws_accreditation', '.xlsx'])
          output_file.close

          result = execute_curl_download(config, output_file)

          yield result
        ensure
          if output_file
            output_file.close unless output_file.closed?
            output_file.unlink
          end
        end
      end

      # Executes curl command to download the XLSX file
      #
      # @param config [XlsxConfiguration] Configuration with URL
      # @param output_file [Tempfile] Temporary output file for downloaded content
      # @return [Hash] Result hash with success/error information
      def self.execute_curl_download(config, output_file)
        command = [
          'curl', '-sS',
          '--ntlm',
          '-u', "#{config.username}:#{config.password}",
          '--max-time', '120',
          '--connect-timeout', '30',
          '-o', output_file.path,
          '-w', '%<http_code>s\n%<content_type>s',
          config.url
        ]

        stdout, stderr, status = Open3.capture3(*command)

        process_curl_result(stdout, stderr, status, output_file.path)
      end

      # Processes curl command result and returns success or error hash
      #
      # @param stdout [String] Curl stdout containing HTTP status and content-type from -w flag
      # @param stderr [String] Curl stderr containing error messages
      # @param status [Process::Status] Exit status of curl command
      # @param file_path [String] Path to the downloaded file
      # @return [Hash] Result hash with success/error information
      def self.process_curl_result(stdout, stderr, status, file_path)
        # Handle curl exit codes
        return handle_curl_error(status.exitstatus, stderr) unless status.success?

        # Parse curl -w output: "200\napplication/vnd.openxmlformats..."
        lines = stdout.strip.split("\n")
        http_code = lines[0]&.strip
        content_type = lines[1]&.strip&.split(';')&.first&.strip || ''

        # Validate HTTP status
        if http_code == '401'
          return handle_error('unauthorized', StandardError.new('Unauthorized'), :unauthorized,
                              'GCLAWS XLSX unauthorized')
        end

        unless http_code == '200'
          return handle_error('http_error', StandardError.new("HTTP #{http_code}"),
                              :bad_gateway, "GCLAWS XLSX request failed with status #{http_code}")
        end

        # Validate content type
        unless content_type == XLSX_CONTENT_TYPE
          return handle_error('invalid_content_type', StandardError.new(content_type), :unprocessable_entity,
                              "Invalid content type: #{content_type}")
        end

        { success: true, file_path: }
      end

      # Handles curl-specific errors based on exit code
      #
      # @param exit_code [Integer] The curl exit code
      # @param stderr [String] Error message from curl
      # @return [Hash] Error result hash
      def self.handle_curl_error(exit_code, stderr)
        case exit_code
        when 28
          handle_error('timeout', StandardError.new(stderr), :request_timeout, 'GCLAWS XLSX download timed out')
        when 6, 7
          handle_error('connection_failed', StandardError.new(stderr), :service_unavailable,
                       'GCLAWS XLSX service unavailable')
        when 22
          # HTTP error (with -f flag) - could be 401 or 5xx
          # Try to extract status from stderr
          if stderr.include?('401')
            handle_error('unauthorized', StandardError.new(stderr), :unauthorized, 'GCLAWS XLSX unauthorized')
          else
            handle_error('http_error', StandardError.new(stderr), :bad_gateway,
                         "GCLAWS XLSX HTTP error: #{stderr}")
          end
        else
          handle_error('unexpected', StandardError.new("Exit code #{exit_code}: #{stderr}"),
                       :internal_server_error, "GCLAWS XLSX unexpected curl error: #{stderr}")
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

      private_class_method :execute_curl_download, :process_curl_result,
                           :handle_curl_error, :handle_error, :notify_slack_error,
                           :log_to_slack_channel, :log_error
    end
  end
end
