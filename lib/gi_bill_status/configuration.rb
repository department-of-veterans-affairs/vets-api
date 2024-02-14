require 'common/client/configuration/rest'

module GiBillStatus
    ##
    # HTTP client configuration for the {GiBillStatus::Service},
    # sets the base path, the base request headers, and a service name for breakers and metrics.
    #
    class Configuration < Common::Client::Configuration::Rest
        self.read_timeout = Settings.caseflow.timeout || 20 # using the same timeout as lighthouse

        ##
        # @return [String] Base path for GI Bill Status URLs.
        #
        def base_path
            Settings.gi_bill_status.url
        end

        ##
        # @return [String] Service name to use in breakers and metrics.
        #
        def service_name
            'GiBillStatus'
        end

        ##
        # @return [Hash] The basic headers required for any decision review API call.
        #
        def self.base_request_headers
            super.merge('apiKey' => Settings.gi_bill_status.api_key)
        end
  
        ##
        # Creates the a connection with parsing json and adding breakers functionality.
        #
        # @return [Faraday::Connection] a Faraday connection instance.
        #
        def connection
            @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
                faraday.use      :breakers
                faraday.use      Faraday::Response::RaiseError

                faraday.request :multipart
                faraday.request :json

                faraday.response :betamocks if mock_enabled?
                faraday.response :json
                faraday.adapter Faraday.default_adapter
            end
        end

        ##
        # @return [Boolean] Should the service use mock data in lower environments.
        #
        def mock_enabled?
            Settings.gi_bill_status.mock || false
        end
  
        def breakers_error_threshold
            80 # breakers will be tripped if error rate reaches 80% over a two minute period.
        end
    end
end
  