# frozen_string_literal: true

# Configuration for downloading XLSX files from GCLAWS SSRS using NTLM authentication via curl
#
module RepresentationManagement
  module GCLAWS
    class XlsxConfiguration
      attr_reader :url, :username, :password

      def initialize
        @url = settings.url
        @username = settings.username
        @password = settings.password
      end

      # Extracts the hostname from the configured URL
      #
      # @return [String] The hostname (e.g., 'ssrs.example.com')
      def hostname
        URI.parse(url).host
      end

      private

      def settings
        Settings.gclaws.accreditation_xlsx
      end
    end
  end
end
