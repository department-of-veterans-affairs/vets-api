# frozen_string_literal: true

# Configuration for downloading XLSX files from GCLAWS SSRS using NTLM authentication via curl
#
module RepresentationManagement
  module GCLAWS
    class XlsxConfiguration
      class ConfigurationError < StandardError; end

      attr_reader :url, :username, :password

      def initialize
        @url = validate_and_coerce_url(settings.url)
        @username = validate_and_coerce_credential(settings.username, 'username')
        @password = validate_and_coerce_credential(settings.password, 'password')
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

      # Validates and coerces URL setting value
      #
      # @param value [Object] The URL value from settings (may be nil, String, or other type)
      # @param field_name [String] Name of the field for error messages
      # @return [String] The validated URL string
      # @raise [ConfigurationError] If URL is missing or malformed
      def validate_and_coerce_url(value)
        url_string = value.to_s.strip

        if url_string.empty?
          raise ConfigurationError, 'GCLAWS accreditation_xlsx URL is missing or empty. ' \
                                    'Check Settings.gclaws.accreditation_xlsx.url configuration.'
        end

        # Validate URL can be parsed and has required components
        begin
          uri = URI.parse(url_string)
          unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
            raise ConfigurationError, "GCLAWS accreditation_xlsx URL must be HTTP or HTTPS, got: #{url_string}"
          end
          raise ConfigurationError, "GCLAWS accreditation_xlsx URL missing hostname: #{url_string}" unless uri.host
        rescue URI::InvalidURIError => e
          raise ConfigurationError, "GCLAWS accreditation_xlsx URL is malformed: #{e.message}"
        end

        url_string
      end

      # Validates and coerces credential setting values (username/password)
      #
      # @param value [Object] The credential value from settings (may be nil, String, Integer, or other type)
      # @param field_name [String] Name of the field for error messages
      # @return [String] The validated credential string
      # @raise [ConfigurationError] If credential is missing or empty
      def validate_and_coerce_credential(value, field_name)
        credential = value.to_s.strip

        if credential.empty?
          raise ConfigurationError, "GCLAWS accreditation_xlsx #{field_name} is missing or empty. " \
                                    "Check Settings.gclaws.accreditation_xlsx.#{field_name} configuration."
        end

        credential
      end
    end
  end
end
