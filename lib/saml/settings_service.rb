# frozen_string_literal: true
require 'memoist'

module SAML
  # This class is responsible for putting together a complete ruby-saml
  # SETTINGS object, meaning, our static SP settings + the IDP settings
  # which must be fetched once and only once via IDP metadata.
  class SettingsService
    class << self
      extend Memoist

      METADATA_RETRIES = 3
      OPEN_TIMEOUT = 2
      TIMEOUT = 15

      def saml_settings
        OneLogin::RubySaml::IdpMetadataParser.new.parse(metadata, settings: settings)
      rescue => e
        Rails.logger.error "SAML::SettingService failed to parse SAML metadata: #{e.message}"
        raise e
      end
      memoize :saml_settings

      private

      def connection
        Faraday.new(Settings.saml.metadata_url) do |conn|
          conn.options.open_timeout = OPEN_TIMEOUT
          conn.options.timeout = TIMEOUT
          conn.adapter :net_http
        end
      end
      memoize :connection

      def metadata
        attempt ||= 0
        response = connection.get
        raise SAML::InternalServerError, response.status if (400..504).cover? response.status.to_i
        response.body
      rescue StandardError => e
        attempt += 1
        msg = "Failed to load SAML metadata: #{e.message}: try #{attempt} of #{METADATA_RETRIES}"
        attempt >= METADATA_RETRIES ? Rails.logger.error(msg) : Rails.logger.warn(msg)
        if attempt < METADATA_RETRIES
          sleep attempt * 0.25
          retry
        end
      end

      def settings
        settings = OneLogin::RubySaml::Settings.new

        settings.certificate = Settings.saml.certificate
        settings.private_key = Settings.saml.key
        settings.issuer = Settings.saml.issuer
        settings.assertion_consumer_service_url = Settings.saml.callback_url

        settings.security[:authn_requests_signed] = true
        settings.security[:logout_requests_signed] = true
        settings.security[:embed_sign] = false
        settings.security[:signature_method] = XMLSecurity::Document::RSA_SHA1

        settings
      end
    end
  end
  class InternalServerError < StandardError
  end
end
