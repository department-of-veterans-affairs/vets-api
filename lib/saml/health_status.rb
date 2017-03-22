# frozen_string_literal: true
require 'saml/settings_service'
require 'sentry_logging'

module SAML
  module StatusMessages
    NOT_ATTEMPTED = 'SAML Metadata retrieve not yet attempted'
    MISSING       = 'SAML Metadata retrieve attempted, but none returned'
    CERT_INVALID  = 'IDP certificate is invalid'
  end

  class HealthStatus
    class << self
      include SentryLogging
      include StatusMessages

      def healthy?
        error_message.empty?
      end

      def error_message
        return StatusMessages::NOT_ATTEMPTED unless fetch_attempted?
        return StatusMessages::MISSING       unless metadata_retrieved?
        return StatusMessages::CERT_INVALID  unless idp_cert_valid?
        ''
      end

      def fetch_attempted?
        SettingsService.fetch_attempted == true
      end

      def metadata_retrieved?
        # guard against actually going and retrieving SAML metadata within the check itself
        return false unless fetch_attempted?
        SettingsService.merged_saml_settings&.idp_sso_target_url&.blank? == false
      end

      private

      def idp_cert_valid?
        return false unless fetch_attempted? && metadata_retrieved?
        formatted_cert = OneLogin::RubySaml::Utils.format_cert(SettingsService.merged_saml_settings.idp_cert)
        # formatted_cert = OneLogin::RubySaml::Utils.format_cert("MIIDqDCCApACCQDIJk8QWWTemDANBgkqhkiG9w0BAQsFADCBlTELMAkGA1UEBhMC\rVVMxETAPBgNVBAgTCFZpcmdpbmlhMQ8wDQYDVQQHELm1lMRQwEgYDVQQLEwtFbmdpbmVlcmluZzEaMBgGA1UEAxMRc2lnbmluZy5p\rZHAuaWQubWUxIDAeBgkqhkiG9w0BCQEWEWVuZ2luZWVyaW5nQGlkLm1lMB4XDTE3\rMDMxNzE3NTA0OVoXDTE4MDMxNzE3NTA0OVowgZUxCzAJBgNVBAYTAlVTMREwDwYD\rVQQIEwhWaXJnaW5pYTEPMA0GA1UEBxMGTWNMZWFuMQ4wDAYDVQQKEwVJRC5tZTEU\rMBIGA1UECxMLRW5naW5lZXJpbmcxGjAYBgNVBAMTEXNpZ25pbmcuaWRwLmlkLm1l\rMSAwHgYJKoZIhvcNAQkBFhFlbmdpbmVlcmluZ0BpZC5tZTCCASIwDQYJKoZIhvcN\rAQEBBQADggEPADCCAQoCggEBAL0yxuoRxW7tXV68v9Ka5eAq2y6QI4TIPY+/R1lj\r7UQmy5qVk34H+JrIRhcTk2X/xKFjOXODh6vA7He5BqY0ILKAA0T+kKtKal1lyOJE\rqPsZoWrQnGPxlw4jGEprHqj7qyfPD2c6SauVskt+P8/u7RiLt0NXU8IGW2kS81Lh\rOVxTOM4vuuP9Pi72ihEKpos+vmugI/yVxDPhku4airyZz7JGQfxu146S+xQbYus9\r+O2R7pYIawGgjZcFIMSNcA8YGSp6Z9eeKua/lqgB+uekQvpIrsFQlq0zFuvyO/6l\rh6OHpxFqohzvVJFdkmeeDzyealUFrB9b2wOAgyBz9PgeBIcCAwEAATANBgkqhkiG\r9w0BAQsFAAOCAQEAY5V+CbhwNsdo88k1BVuCe8ssx/mcJ2pfayQ6A27+jpNwnS1/\r0dPY8pL7AuyN9e3i7gfShiKsbH4WS39b6UM+7KP9/Lm2Sx63Iv1HD7PLNJbPUzyK\rHOfTYTd62Iga0mpuVjjij47u9/f4lgvdCtEF4a81j8KjJjNs7+PYNs/mObvJM9jL\rs9KLaN4lKhJ/rMLqeZ0E6UHO3I/SM6t9bBGfIjKxvr3Tq6bTrQfZxu57+Nj/+hLE\roG1xZ5nub6hddMobaBBVK5goETgYQASPYKcpcNdjeriHXYQt37zwM6PK3C3tFyX/\rxnJgHVBDUrcHFR/9qqh14MADXEkv+Xm9sC9jUw==")
        begin
          OpenSSL::X509::Certificate.new(formatted_cert)
          return true
        rescue OpenSSL::X509::CertificateError => e
          # if cert is invalid --> "OpenSSL::X509::CertificateError: nested asn1 error"
          log_exception_to_sentry(e)
          return false
        end
      end
    end
  end
end
