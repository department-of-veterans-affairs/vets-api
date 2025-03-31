# frozen_string_literal: true

module BipClaims
  class Configuration < Common::Client::Configuration::REST
    def base_path
      Settings.bip.claims.url
    end

    def service_name
      'BipClaims'
    end

    ##
    # Creates the a connection with middleware for mapping errors, parsing json, and adding breakers functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.request :json

        faraday.response :raise_custom_error, error_prefix: service_name
        faraday.response :betamocks if mock_enabled?
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    ##
    # @return [Boolean] Should the service use mock data in lower environments.
    #
    def mock_enabled?
      [true, 'true'].include?(Settings.bip.claims.mock)
    end
  end
end
