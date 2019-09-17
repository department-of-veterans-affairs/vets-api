# frozen_string_literal: true

module SAML
  # This class is responsible for putting together a complete ruby-saml
  # SETTINGS object, meaning, our static SP settings + the IDP settings
  # loaded from a file
  module SSOeSettingsService
    class << self
      def saml_settings(options = {})
        settings = base_settings.dup
        options.each do |option, value|
          next if value.nil?

          settings.send("#{option}=", value)
        end
        settings
      end

      def base_settings
        if SSOeHealthStatus.healthy?
          merged_saml_settings
        else
          log_message_to_sentry(SSOeHealthStatus.error_message, :error) unless fetch_attempted.nil?
          refresh_saml_settings
        end
      end

      def merged_saml_settings
        metadata = get_metadata
        return nil if metadata.nil?

        begin
          merged_settings = OneLogin::RubySaml::IdpMetadataParser.new.parse(metadata, settings: settings)
          merged_settings.name_identifier_format = 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'
          merged_settings
        rescue => e
          log_message_to_sentry("SAML::SettingService failed to parse SAML metadata: #{e.message}", :error)
          raise e
        end
      end
      memoize :merged_saml_settings

      private

      def refresh_saml_settings
        # passing true reloads cache. See: https://github.com/matthewrudy/memoist#usage
        merged_saml_settings(true)
      end

      def connection
        Faraday.new(Settings.saml.metadata_url) do |conn|
          conn.options.open_timeout = OPEN_TIMEOUT
          conn.options.timeout = TIMEOUT
          conn.adapter :net_http
        end
      end
      memoize :connection

      def get_metadata
        @fetch_attempted = true
        attempt ||= 0
        response = connection.get
        raise SAML::InternalServerError, response.status if (400..504).cover? response.status.to_i

        response.body
      rescue => e
        attempt += 1
        msg = "Failed to load SAML metadata: #{e.message}: try #{attempt} of #{METADATA_RETRIES}"
        if attempt < METADATA_RETRIES
          log_message_to_sentry(msg, :warn)
          sleep attempt * 0.25
          retry
        else
          log_message_to_sentry(msg, :error)
        end
      end

      def settings
        idp_metadata_parser = OneLogin::RubySaml::IdpMetadataParser.new
        settings = idp_metadata_parser.parse(File.read(Settings.saml_ssoe.idp_metadata_file))

        settings.certificate = Settings.saml_ssoe.certificate
        settings.private_key = Settings.saml_ssoe.key
        settings.certificate_new = Settings.saml_ssoe.certificate_new
        settings.issuer = Settings.saml_ssoe.issuer
        settings.assertion_consumer_service_url = Settings.saml_ssoe.callback_url

        settings.security[:authn_requests_signed] = true
        settings.security[:logout_requests_signed] = true
        settings.security[:embed_sign] = false
        settings.security[:signature_method] = XMLSecurity::Document::RSA_SHA1
        # TODO: Enable these after initial integration with SSOe
        # settings.security[:want_assertions_signed] = true
        # settings.security[:want_assertions_encrypted] = true
        # TODO: Add this to configuration if metadata is not accurate
        # result.idp_sso_target_url = Settings.saml_ssoe.idp_sso_url
        settings
      end
    end
  end
end
