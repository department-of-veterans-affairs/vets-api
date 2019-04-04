# frozen_string_literal: true

require 'appeals/middleware/errors'
require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_error'

module Appeals
  ##
  # HTTP client configuration for the {Appeals::Service},
  # sets the base path, a default timeout, and a service name for breakers and metrics.
  #
  class Configuration < Common::Client::Configuration::REST
    ##
    # @return [String] The auth token for the appeals service.
    #
    def app_token
      Settings.appeals.app_token
    end

    ##
    # @return [String] Base path for appeals URLs.
    #
    def base_path
      Settings.appeals.host
    end

    ##
    # @return [String] Service name to use in breakers and metrics.
    #
    def service_name
      'AppealsStatus'
    end

    ##
    # Creates the a connection with middleware for mapping errors, parsing json, and adding breakers functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use :breakers
        faraday.request :json

        faraday.response :raise_error, error_prefix: service_name
        faraday.response :appeals_errors
        faraday.response :betamocks if mock_enabled?
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    ##
    # @return [Boolean] Should the service use mock data in lower environments.
    #
    def mock_enabled?
      [true, 'true'].include?(Settings.appeals.mock)
    end
  end
end
