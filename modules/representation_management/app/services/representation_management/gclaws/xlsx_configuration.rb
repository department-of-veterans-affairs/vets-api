# frozen_string_literal: true

require 'httpclient'

# HTTPClient configuration for downloading XLSX files from GCLAWS SSRS using NTLM authentication
#
module RepresentationManagement
  module GCLAWS
    class XlsxConfiguration
      attr_reader :url

      def initialize
        @url = settings.url
        @username = settings.username
        @password = settings.password
      end

      # Returns an HTTPClient configured with NTLM authentication and SSL
      #
      # @return [HTTPClient] Configured HTTP client with NTLM auth and SSL settings
      def connection
        client = HTTPClient.new
        configure_ssl(client)
        configure_ntlm_auth(client)
        client
      end

      private

      # Configures SSL settings for the HTTPClient
      #
      # Uses the system CA certificate store which includes VA certs from import-va-certs.sh
      #
      # @param client [HTTPClient] The HTTP client to configure
      def configure_ssl(client)
        client.ssl_config.set_default_paths
      end

      # Configures NTLM authentication for the HTTPClient
      #
      # NTLM requires using the negotiate_auth handler, not basic set_auth.
      # Username should be in DOMAIN\username format if domain is required.
      #
      # @param client [HTTPClient] The HTTP client to configure
      def configure_ntlm_auth(client)
        domain = URI.parse(url).host
        client.set_auth(domain, username, password)

        # Force NTLM authentication by configuring the www_auth negotiate handler
        client.www_auth.negotiate_auth.set(domain, username, password)
      end

      attr_reader :username, :password

      def settings
        Settings.gclaws.accreditation_xlsx
      end
    end
  end
end
