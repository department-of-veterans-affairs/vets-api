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
