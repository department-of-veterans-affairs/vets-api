# frozen_string_literal: true

require_relative 'base'

module Common
  module Client
    module Configuration
      ##
      # Configuration for SOAP based services.
      #
      # @example Create a configuration and use it in a service.
      #   class MyConfiguration < Common::Client::Configuration::REST
      #     def base_path
      #       Settings.my_service.url
      #     end
      #
      #     def service_name
      #       'MyServiceName'
      #     end
      #
      #     def connection
      #       Faraday.new(base_path, headers: base_request_headers, request: request_opts, ssl: ssl_opts) do |conn|
      #         conn.use :breakers
      #         conn.request :soap_headers
      #
      #         conn.response :soap_parser
      #         conn.response :betamocks if Settings.my_service.mock
      #         conn.adapter Faraday.default_adapter
      #       end
      #     end
      #   end
      #
      #   class MyService < Common::Client::Base
      #     configuration MyConfiguration
      #   end
      #
      class SOAP < Base
        self.request_types = %i[post].freeze
        self.base_request_headers = {
          'Accept' => 'text/xml;charset=UTF-8',
          'Content-Type' => 'text/xml;charset=UTF-8',
          'User-Agent' => user_agent
        }.freeze

        ##
        # Reads in the SSL cert to use for the connection
        #
        # @return OpenSSL::X509::Certificate cert instance
        #
        def ssl_cert
          OpenSSL::X509::Certificate.new(File.read(self.class.ssl_cert_path))
        rescue => e
          # :nocov:
          unless allow_missing_certs?
            Rails.logger.warn "Could not load #{service_name} SSL cert: #{e.message}"
            raise e if Rails.env.production?
          end
          nil
          # :nocov:
        end

        ##
        # Reads in the SSL key to use for the connection
        #
        # @return OpenSSL::PKey::RSA key instance
        #
        def ssl_key
          OpenSSL::PKey::RSA.new(File.read(self.class.ssl_key_path))
        rescue => e
          # :nocov:
          Rails.logger.warn "Could not load #{service_name} SSL key: #{e.message}"
          raise e if Rails.env.production?

          nil
          # :nocov:
        end

        ##
        # Used to allow testing without SSL certs in place. Override this method in sub-classes.
        #
        # @return Boolean false by default
        #
        def allow_missing_certs?
          false
        end
      end
    end
  end
end
