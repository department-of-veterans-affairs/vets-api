module SAML
  SETTINGS = OneLogin::RubySaml::Settings.new

  SETTINGS.certificate  = File.read(ENV["CERTIFICATE_FILE"]) unless Rails.env.test?
  SETTINGS.private_key  = File.read(ENV["KEY_FILE"]) unless Rails.env.test?
  SETTINGS.issuer       = ENV["SAML_ISSUER"] || ""

  # This is conifgured per relying party on the ID.me side; we should look into providing
  # a metadata URL: https://github.com/department-of-veterans-affairs/platform-team/issues/43
  # SETTINGS.assertion_consumer_service_url = "http://localhost:3000/auth/saml/callback"

  # ---------------------------------------------------------------
  # This will get moved out of here and will be set per application
  # To require just a username and password, use "authentication" as the context; for full identity proofing, use the LOA3 url.
  SETTINGS.authn_context                  = "authentication"
  #SAML_SETTINGS.authn_context            = "http://idmanagement.gov/ns/assurance/loa/3"

  parser = OneLogin::RubySaml::IdpMetadataParser.new
  parser.parse_remote("https://api.idmelabs.com/saml/metadata", true, {settings: SETTINGS})
end

