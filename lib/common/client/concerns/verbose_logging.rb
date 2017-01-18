# frozen_string_literal: true
module Common
  module Client
    module VerboseLogging
      # logs curl output and response body
      def log_curl_and_response_ouput(connection)
        log_curl_output(connection)
        log_response_output(connection)
      end

      # generating curl output in logs
      def log_curl_output(connection)
        connection.request(:curl, ::Logger.new(STDOUT), :warn) if safe_to_log?
      end

      # logs response body
      def log_response_output(connection)
        connection.response(:logger, ::Logger.new(STDOUT), bodies: true) if safe_to_log?
      end

      def safe_to_log?
        !Rails.env.production?
      end
    end
  end
end
