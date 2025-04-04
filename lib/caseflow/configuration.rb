# frozen_string_literal: true

require 'common/client/middleware/response/caseflow_errors'
require 'common/client/configuration/rest'
require 'common/client/middleware/response/raise_custom_error'

module Caseflow
  ##
  # HTTP client configuration for the {Caseflow::Service},
  # sets the base path, a default timeout, and a service name for breakers and metrics.
  #
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.caseflow.timeout || 20
    ##
    # @return [String] The auth token for the caseflow service.
    #
    def app_token
      Settings.caseflow.app_token
    end

    ##
    # @return [String] Base path for caseflow URLs.
    #
    def base_path
      Settings.caseflow.host
    end

    ##
    # @return [String] Service name to use in breakers and metrics.
    #
    def service_name
      'CaseflowStatus'
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
        faraday.response :caseflow_errors
        faraday.response :betamocks if mock_enabled?
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    ##
    # @return [Boolean] Should the service use mock data in lower environments.
    #
    def mock_enabled?
      [true, 'true'].include?(Settings.caseflow.mock)
    end
  end
end
