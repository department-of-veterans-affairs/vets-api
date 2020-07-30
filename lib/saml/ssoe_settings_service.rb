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
        idp_metadata_parser = OneLogin::RubySaml::IdpMetadataParser.new
        settings = idp_metadata_parser.parse(File.read(Settings.saml_ssoe.idp_metadata_file))

        if pki_needed?
          settings.certificate = Settings.saml_ssoe.certificate
          settings.private_key = Settings.saml_ssoe.key
          settings.certificate_new = Settings.saml_ssoe.certificate_new
        end
        settings.sp_entity_id = Settings.saml_ssoe.issuer
        settings.assertion_consumer_service_url = Settings.saml_ssoe.callback_url
        settings.compress_request = false

        settings.security[:authn_requests_signed] = Settings.saml_ssoe.request_signing
        settings.security[:want_assertions_signed] = Settings.saml_ssoe.response_signing
        settings.security[:want_assertions_encrypted] = Settings.saml_ssoe.response_encryption
        settings.security[:embed_sign] = false
        settings.security[:signature_method] = XMLSecurity::Document::RSA_SHA1
        settings
      end

      def pki_needed?
        Settings.saml_ssoe.request_signing || Settings.saml_ssoe.response_encryption
      end
    end
  end
end
