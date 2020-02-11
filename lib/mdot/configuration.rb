# frozen_string_literal: true

require 'common/client/configuration/rest'

module MDOT
  class Configuration < Common::Client::Configuration::REST
    ##
    # @return [String] Base path for decision review URLs.
    #
    def base_path
      Settings.mdot.url
    end

    def service_name
      'MDOT'
    end

    ##
    # @return [Hash] The basic headers required for any decision review API call.
    #
    def self.base_request_headers
      super.merge('apiKey' => Settings.mdot.api_key)
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

        faraday.request :json

        faraday.response :betamocks if mock_enabled?
        faraday.response :snakecase, symbolize: false
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    ##
    # @return [Boolean] Should the service use mock data in lower environments.
    #
    def mock_enabled?
      Settings.medical_devices.mock || false
    end
  end
end
