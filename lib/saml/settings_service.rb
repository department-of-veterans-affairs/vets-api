# frozen_string_literal: true
module SAML
  # This class is responsible for putting together a complete ruby-saml
  # SETTINGS object, meaning, our static SP settings + the IDP settings
  # which must be fetched once and only once via IDP metadata.
  class SettingsService
    attr_reader :saml_settings

    METADATA_URI = URI(SAML_CONFIG['metadata_url'])

    def initialize
      @saml_settings = create_settings_from_metadata
    end

    def self.metadata
      return @metadata if defined?(@metadata)
      http = Net::HTTP.new(METADATA_URI.host, METADATA_URI.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      get = Net::HTTP::Get.new(METADATA_URI.request_uri)
      @metadata = http.request(get).body
    end

    private

    def settings
      # populate with SP settings
      settings = OneLogin::RubySaml::Settings.new
      settings.certificate  = SAML_CONFIG['certificate']
      settings.private_key  = SAML_CONFIG['key']
      settings.issuer       = SAML_CONFIG['issuer']
      settings.assertion_consumer_service_url = SAML_CONFIG['callback_url']

      settings.security[:authn_requests_signed]   = true
      settings.security[:embed_sign]              = false
      settings.security[:signature_method] = XMLSecurity::Document::RSA_SHA1

      settings
    end

    ## Makes an external web call to get IDP metadata and populates SETTINGS
    def create_settings_from_metadata
      parser = OneLogin::RubySaml::IdpMetadataParser.new
      parser.parse(self.class.metadata, settings: settings)
    end
  end
end
