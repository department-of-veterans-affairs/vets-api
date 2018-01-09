# frozen_string_literal: true

require_relative 'base'

module Common
  module Client
    module Configuration
      class SOAP < Base
        self.request_types = %i[post].freeze
        self.base_request_headers = {
          'Accept' => 'text/xml;charset=UTF-8',
          'Content-Type' => 'text/xml;charset=UTF-8',
          'User-Agent' => user_agent
        }.freeze

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

        def ssl_key
          OpenSSL::PKey::RSA.new(File.read(self.class.ssl_key_path))
        rescue => e
          # :nocov:
          Rails.logger.warn "Could not load #{service_name} SSL key: #{e.message}"
          raise e if Rails.env.production?
          nil
          # :nocov:
        end

        def allow_missing_certs?
          false
        end
      end
    end
  end
end
