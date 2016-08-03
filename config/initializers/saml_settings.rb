module SAML

  cert_file = ENV["CERTIFICATE_FILE"]
  key_file = ENV["KEY_FILE"]

  CERTFILES_EXIST = cert_file && File.exists?(cert_file) &&
                    key_file && File.exists?(key_file)
  NO_LOGIN_MODE = Rails.env.test? || !CERTFILES_EXIST
  SETTINGS = OneLogin::RubySaml::Settings.new

  if NO_LOGIN_MODE
    msg = "No SAML settings configured, starting up in NO LOGIN MODE."\
          " ID.me integration will not function."
    Rails.logger.warn msg
  else
    SETTINGS.certificate  = File.read(ENV["CERTIFICATE_FILE"])
    SETTINGS.private_key  = File.read(ENV["KEY_FILE"])
    SETTINGS.issuer       = ENV["SAML_ISSUER"] || ""
  end

  # This is configured per relying party on the ID.me side; we should look into providing
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

