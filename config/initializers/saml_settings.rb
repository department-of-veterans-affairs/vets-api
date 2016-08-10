module SAML
  SETTINGS = OneLogin::RubySaml::Settings.new

  SETTINGS.certificate  = File.read(ENV["CERTIFICATE_FILE"])
  SETTINGS.private_key  = File.read(ENV["KEY_FILE"])
  SETTINGS.issuer       = ENV["SAML_ISSUER"]
  SETTINGS.assertion_consumer_service_url = ENV["CALLBACK_URL"]

  # ---------------------------------------------------------------
  # This will get moved out of here and will be set per application
  # To require just a username and password, use "authentication" as the context;
  # for full identity proofing, use the LOA3 url.
  SETTINGS.authn_context                  = "authentication"
  #SAML_SETTINGS.authn_context            = "http://idmanagement.gov/ns/assurance/loa/3"

  parser = OneLogin::RubySaml::IdpMetadataParser.new
  parser.parse_remote(ENV["METADATA_URL"], true, {settings: SETTINGS})
end

