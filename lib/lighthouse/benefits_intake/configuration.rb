# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'faraday/multipart'

module BenefitsIntake
  ##
  # HTTP client configuration for the {BenefitsIntake::Service},
  # sets the base path, the base request headers, and a service name for breakers and metrics.
  #
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.lighthouse.benefits_intake.timeout || 20

    ##
    # @return [Config::Options] Settings for benefits_claims API.
    #
    def intake_settings
      Settings.lighthouse.benefits_intake
    end

    ##
    # @return [String] Base path.
    #
    def service_path
      url = [intake_settings.host, intake_settings.path, intake_settings.version]
      url.map { |segment| segment.sub(%r{^/}, '').chomp('/') }.join('/')
    end

    ##
    # @return [String] Service name to use in breakers and metrics.
    #
    def service_name
      'BenefitsIntake'
    end

    ##
    # @return [Hash] The basic headers required for any Lighthouse API call
    #
    def self.base_request_headers
      key = Settings.lighthouse.benefits_intake.api_key
      raise "No api_key set for benefits_intake. Please set 'lighthouse.benefits_intake.api_key'" if key.nil?

      super.merge('apikey' => key)
    end

    ##
    # Creates a connection with json parsing and breaker functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      @conn ||= Faraday.new(service_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.use Faraday::Response::RaiseError

        faraday.request :multipart
        faraday.request :json

        faraday.response :betamocks if use_mocks?
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    ##
    # @return [Boolean] Should the service use mock data in lower environments.
    #
    def use_mocks?
      intake_settings.use_mocks || false
    end

    def breakers_error_threshold
      80 # breakers will be tripped if error rate reaches 80% over a two minute period.
    end
  end
end
