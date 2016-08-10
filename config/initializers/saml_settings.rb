module SAML

  CONFIG = Rails.application.config_for(:saml).freeze
  SETTINGS = OneLogin::RubySaml::Settings.new

  unless Rails.env.test?
    Figaro.require_keys("CERTIFICATE_FILE", "KEY_FILE")
    SETTINGS.certificate  = File.read(ENV["CERTIFICATE_FILE"])
    SETTINGS.private_key  = File.read(ENV["KEY_FILE"])
  end
  SETTINGS.issuer         = CONFIG["issuer"]
  SETTINGS.assertion_consumer_service_url = CONFIG["callback_url"]

  # ---------------------------------------------------------------
  # This will get moved out of here and will be set per application
  # To require just a username and password, use "authentication" as the context;
  # for full identity proofing, use the LOA3 url.
  SETTINGS.authn_context                  = "authentication"
  #SAML_SETTINGS.authn_context            = "http://idmanagement.gov/ns/assurance/loa/3"

  parser = OneLogin::RubySaml::IdpMetadataParser.new
  parser.parse_remote(CONFIG["metadata_url"], true, {settings: SETTINGS})
end

