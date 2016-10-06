# frozen_string_literal: true
module SAML
  SAML_CONFIG = Rails.application.config_for(:saml).freeze

  # populate with SP settings
  SETTINGS = OneLogin::RubySaml::Settings.new
  SETTINGS.certificate  = SAML_CONFIG['certificate']
  SETTINGS.private_key  = SAML_CONFIG['key']
  SETTINGS.issuer       = SAML_CONFIG['issuer']
  SETTINGS.assertion_consumer_service_url = SAML_CONFIG['callback_url']

  # This will get moved out of here and will be set per application
  # To require just a username and password, use "authentication" as the context;
  # for full identity proofing, use the LOA3 url.
  SETTINGS.authn_context                  = 'authentication'
  # SAML_SETTINGS.authn_context            = "http://idmanagement.gov/ns/assurance/loa/3"
end

=begin
  # TODO this stuff comes from ID.me xml metadata - we can hardcode/mock this elsewhere for rspecs
  SETTINGS.idp_cert="MIIDqDCCApACCQC2yH1Wg794eDANBgkqhkiG9w0BAQsFADCBlTELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMQ8wDQYDVQQHEwZNY0xlYW4xDjAMBgNVBAoTBUlELm1lMRQwEgYDVQQLEwtFbmdpbmVlcmluZzEaMBgGA1UEAxMRc2lnbmluZy5pZHAuaWQubWUxIDAeBgkqhkiG9w0BCQEWEWVuZ2luZWVyaW5nQGlkLm1lMB4XDTE2MDQyNjE0MTgyN1oXDTE3MDQyNjE0MTgyN1owgZUxCzAJBgNVBAYTAlVTMREwDwYDVQQIEwhWaXJnaW5pYTEPMA0GA1UEBxMGTWNMZWFuMQ4wDAYDVQQKEwVJRC5tZTEUMBIGA1UECxMLRW5naW5lZXJpbmcxGjAYBgNVBAMTEXNpZ25pbmcuaWRwLmlkLm1lMSAwHgYJKoZIhvcNAQkBFhFlbmdpbmVlcmluZ0BpZC5tZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL0yxuoRxW7tXV68v9Ka5eAq2y6QI4TIPY+/R1lj7UQmy5qVk34H+JrIRhcTk2X/xKFjOXODh6vA7He5BqY0ILKAA0T+kKtKal1lyOJEqPsZoWrQnGPxlw4jGEprHqj7qyfPD2c6SauVskt+P8/u7RiLt0NXU8IGW2kS81LhOVxTOM4vuuP9Pi72ihEKpos+vmugI/yVxDPhku4airyZz7JGQfxu146S+xQbYus9+O2R7pYIawGgjZcFIMSNcA8YGSp6Z9eeKua/lqgB+uekQvpIrsFQlq0zFuvyO/6lh6OHpxFqohzvVJFdkmeeDzyealUFrB9b2wOAgyBz9PgeBIcCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAifLgGmEGfdM1K/OILDVW0JUsjuV98A1u+h8JNKIwd9K+1j6ONmDYEXlwEZp9DmdhgF0WpCz+ITOgiZS2aDXkKfUNX5vJQf5U43dyNEyS0rDAvgroz+o6YZdrJAIubbuX3jPz7r8QUyDkCRudUS04KHRo+fjuLHebrWhy8FJuliZSijvFFIwPJCJKOP0Sybe7zdtMzuM7C4kudDbAfGY296F5JFNBp8cVQQSOTmW/FPS8n+8rjlDr+QHnstBofsKkvxocek4C2AeQubTpGqYqKQ+yApj2IkxDM8nj7xrVZrsEsB7WEZCoV6WzcaEHmeCdw6hDnRxKw2/3hrarRtJBDg=="
  SETTINGS.idp_cert_fingerprint="74:DC:33:BE:D6:92:69:3F:81:65:F6:CF:ED:55:82:E0:A5:65:B3:32"
  SETTINGS.idp_entity_id='api.idmelabs.com'
  SETTINGS.idp_slo_target_url="https://api.idmelabs.com/saml/SingleLogoutService"
  SETTINGS.idp_sso_target_url="https://api.idmelabs.com/saml/SingleSignOnService"
  SETTINGS.name_identifier_format="urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified"
=end