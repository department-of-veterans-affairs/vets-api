# frozen_string_literal: true

require 'common/client/configuration/base'

module SSOe
  class Configuration < Common::Client::Configuration::SOAP
    def self.ssl_cert_path
      IdentitySettings.mvi.client_cert_path
    end

    def self.ssl_key_path
      IdentitySettings.mvi.client_key_path
    end

    def ssl_options
      if ssl_cert && ssl_key
        {
          client_cert: ssl_cert,
          client_key: ssl_key
        }
      end
    end

    def base_path
      'https://int.services.eauth.va.gov:9303/psim_webservice/dev/IdMSSOeWebService'
    end

    def service_name
      'SSOe'
    end

    def connection
      @connection ||= Faraday.new(base_path,
                                  headers: base_request_headers,
                                  request: request_options,
                                  ssl: ssl_options) do |faraday|
        faraday.request :soap_headers
        faraday.response :soap_parser
        faraday.request(:curl, ::Logger.new(STDOUT), :warn)
        faraday.response(:logger, ::Logger.new(STDOUT), bodies: true)
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end