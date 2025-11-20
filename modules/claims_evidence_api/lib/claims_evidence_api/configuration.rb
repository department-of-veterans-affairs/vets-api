# frozen_string_literal: true

require 'claims_evidence_api/jwt_generator'
require 'common/client/configuration/rest'
require 'faraday/multipart'

module ClaimsEvidenceApi
  # HTTP client configuration for the {ClaimsEvidenceApi::Service::Base},
  class Configuration < Common::Client::Configuration::REST
    self.open_timeout = Settings.claims_evidence_api.timeout.open || 30
    self.read_timeout = Settings.claims_evidence_api.timeout.read || 30

    # @return [Config::Options] Settings for benefits_claims API.
    def service_settings
      Settings.claims_evidence_api
    end

    # @see Common::Client::Configuration::Base#base_path
    # @return [String] Base path.
    def service_path
      service_settings.base_url
    end
    alias base_path service_path

    # @return [String] Service name to use in breakers and metrics.
    def service_name
      'ClaimsEvidenceApi'
    end

    # @return [Hash] The basic headers required for any API call
    def self.base_request_headers
      headers = {}
      super.merge(headers)
    end

    # Creates a connection with json parsing and breaker functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    def connection
      options = {
        headers: base_request_headers,
        request: request_options,
        ssl: { verify: service_settings.ssl }
      }
      @conn ||= Faraday.new(service_path, **options) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.use Faraday::Response::RaiseError

        faraday.request :multipart
        faraday.request :json

        faraday.response :betamocks if use_mocks?
        faraday.response :raise_error, include_request: include_request?
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    # @return [Boolean] Should the service use mock data in lower environments.
    def use_mocks?
      service_settings.mock || false
    end

    # @return [Boolean] Should the service include the request method and url in error messages.
    def include_request?
      service_settings.include_request || false
    end

    # breakers will be tripped if error rate exceeds the threshold over a two minute period.
    def breakers_error_threshold
      service_settings.breakers_error_threshold || 80
    end
  end
end
