# frozen_string_literal: true

module Common
  module Client
    module Configuration
      module Concerns
        module Ssl
          ##
          # Formats SSL options for the connection
          #
          # @return Hash ssl options hash
          #
          def ssl_options
            if ssl_cert && ssl_key
              {
                client_cert: ssl_cert,
                client_key: ssl_key
              }
            end
          end

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
end
