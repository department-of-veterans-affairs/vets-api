# frozen_string_literal: true
module EVSS
  module Letters
    class DownloadConfiguration < EVSS::Letters::Configuration
      self.read_timeout = Settings.evss.letters.timeout || 55

      def connection
        @conn ||= Faraday.new(base_path, request: request_options, ssl: ssl_options) do |faraday|
          faraday.use :breakers
          faraday.use EVSS::ErrorMiddleware
          faraday.use :immutable_headers
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
