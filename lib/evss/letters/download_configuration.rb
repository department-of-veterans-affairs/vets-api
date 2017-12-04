# frozen_string_literal: true
module EVSS
  module Letters
    class DownloadConfiguration < EVSS::Letters::Configuration
      def connection
        @conn ||= Faraday.new(base_path, ssl: ssl_options) do |faraday|
          faraday.options.timeout = DEFAULT_TIMEOUT
          faraday.use :breakers
          faraday.use EVSS::ErrorMiddleware
          faraday.use :immutable_headers
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
