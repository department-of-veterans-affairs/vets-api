# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'faraday/multipart'

# Benefits Processing Data Service (BPDS)
# https://department.va.gov/privacy/wp-content/uploads/sites/5/2024/09/FY24BenefitsProcessingDataServiceBPDSPIA_508.pdf
module BPDS
  # Configuration for BPDS service
  class Configuration < Common::Client::Configuration::REST
    # settings bpds url
    #
    # @return [String] Base path
    def base_path
      Settings.bpds.url
    end

    # service name function
    #
    # @return [String] Service name to use in breakers and metrics.
    def service_name
      'BPDS::Service'
    end

    # generate request headers
    #
    # @return [Hash] The basic headers required for any Lighthouse API call
    def self.base_request_headers
      super.merge('Authorization' => "Bearer #{BPDS::JwtEncoder.new.get_token}")
    end

    # Creates a connection with json parsing and breaker functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    def connection
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options,
                                       ssl: { verify: false }) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.use Faraday::Response::RaiseError

        faraday.request :multipart
        faraday.request :json

        faraday.response :betamocks if mock_enabled?
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    # should the service be mocked
    #
    # @return [Boolean] Should the service use mock data in lower environments.
    def mock_enabled?
      Settings.bpds.mock || false
    end

    # breakers will be tripped if error rate reaches 80% over a two minute period.
    def breakers_error_threshold
      80
    end
  end
end
