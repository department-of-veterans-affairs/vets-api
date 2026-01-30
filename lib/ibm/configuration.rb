# frozen_string_literal: true

require 'common/client/configuration/rest'

module Ibm
  # HTTP client configuration for the {BenefitsIntake::Service},
  # sets the base path, the base request headers, and a service name for breakers and metrics.
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.ibm.timeout || 30

    # @return [Config::Options] Settings for validated-forms API.
    def intake_settings
      Settings.ibm
    end

    # @return [String] Base path.
    def service_path
      url = [intake_settings.host, intake_settings.path, intake_settings.version]
      "https://#{url.map { |segment| segment.sub(%r{^/}, '').chomp('/') }.join('/')}"
    end

    # @return [String] Service name to use in breakers and metrics.
    def service_name
      'MMS'
    end

    # Creates a connection with json parsing and breaker functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    def connection
      @conn ||= Faraday.new(service_path, request: request_options, ssl: ssl_options) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.use Faraday::Response::RaiseError

        faraday.request :json

        faraday.response :betamocks if use_mocks?
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    # @return [Boolean] Should the service use mock data in lower environments.
    def use_mocks?
      intake_settings.use_mocks || false
    end

    # breakers will be tripped if error rate reaches 80% over a two minute period.
    def breakers_error_threshold
      intake_settings.breakers_error_threshold || 80
    end

    def ssl_options
      if ssl_cert && ssl_key
        {
          client_cert: ssl_cert,
          client_key: ssl_key
        }
      end
    end

    def ssl_cert
      return unless intake_settings.client_cert_path

      OpenSSL::X509::Certificate.new(File.read(intake_settings.client_cert_path))
    end

    def ssl_key
      return unless intake_settings.client_key_path

      OpenSSL::PKey::RSA.new(File.read(intake_settings.client_key_path))
    end
  end
end
