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
      # HTTPClient handles NTLM automatically when the server responds with
      # WWW-Authenticate: NTLM. The set_auth method stores credentials that
      # will be used for the NTLM handshake.
      #
      # Username should be in DOMAIN\username format (e.g., 'va\svc_account')
      #
      # @param client [HTTPClient] The HTTP client to configure
      def configure_ntlm_auth(client)
        # Set credentials for the URL - HTTPClient will use these for NTLM when challenged
        client.set_auth(url, username, password)

        # Force negotiate auth to be tried (includes NTLM)
        client.www_auth.basic_auth.challenge(url)
      end

      attr_reader :username, :password

      def settings
        Settings.gclaws.accreditation_xlsx
      end
    end
  end
end
