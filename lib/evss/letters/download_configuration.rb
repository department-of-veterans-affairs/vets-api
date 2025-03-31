# frozen_string_literal: true

module EVSS
  module Letters
    ##
    # Download configuration for {EVSS::Letters}
    #
    class DownloadConfiguration < EVSS::Letters::Configuration
      self.read_timeout = Settings.evss.letters.timeout || 55

      ##
      # @return [Faraday::Connection] A new Faraday connection object based on
      # the configuration set up in EVSS::Letters::Configuration
      #
      def connection
        @conn ||= Faraday.new(base_path, request: request_options, ssl: ssl_options) do |faraday|
          faraday.use(:breakers, service_name:)
          faraday.use EVSS::ErrorMiddleware
          faraday.use :immutable_headers

          faraday.response :betamocks if mock_enabled?
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
