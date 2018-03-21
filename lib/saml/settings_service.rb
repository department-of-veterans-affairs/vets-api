# frozen_string_literal: true

require 'memoist'
require 'sentry_logging'
require 'saml/health_status'
require 'saml/url_service'

module SAML
  # This class is responsible for putting together a complete ruby-saml
  # SETTINGS object, meaning, our static SP settings + the IDP settings
  # which must be fetched once and only once via IDP metadata.
  module SettingsService
    extend URLService

    class << self
      include SentryLogging
      extend Memoist

      attr_reader :fetch_attempted

      METADATA_RETRIES = 3
      OPEN_TIMEOUT = 2
      TIMEOUT = 15

      def saml_settings(options = {})
        if options.any?
          # Make sure we're not changing the settings globally
          settings = base_settings.dup

          options.each do |option, value|
            next if value.nil?
            settings.send("#{option}=", value)
          end

          settings
        else
          base_settings
        end
      end

      def base_settings
        if HealthStatus.healthy?
          merged_saml_settings
        else
          log_message_to_sentry(HealthStatus.error_message, :error) unless fetch_attempted.nil?
          refresh_saml_settings
        end
      end

      def merged_saml_settings
        metadata = get_metadata
        return nil if metadata.nil?
        begin
          OneLogin::RubySaml::IdpMetadataParser.new.parse(metadata, settings: settings)
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
      rescue StandardError => e
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
        settings = OneLogin::RubySaml::Settings.new

        settings.certificate = Settings.saml.certificate
        settings.private_key = Settings.saml.key
        settings.issuer = Settings.saml.issuer
        settings.assertion_consumer_service_url = Settings.saml.callback_url
        settings.certificate_new = Settings.saml.certificate_new

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
