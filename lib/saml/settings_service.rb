# frozen_string_literal: true
module SAML
  # This class is responsible for putting together a complete ruby-saml
  # SETTINGS object, meaning, our static SP settings + the IDP settings
  # which must be fetched once and only once via IDP metadata.
  require 'singleton'
  class SettingsService
    include Singleton

    def saml_settings
      @combined_saml_settings ||= fetch_idp_metadata
    end

    ## Makes an external web call to get IDP metadata and populates SETTINGS
    def fetch_idp_metadata
      parser = OneLogin::RubySaml::IdpMetadataParser.new
      parser.parse_remote(SAML_CONFIG['metadata_url'], true, settings: SETTINGS)
      SETTINGS
    end
  end
end
