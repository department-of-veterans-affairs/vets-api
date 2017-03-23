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

      attr_accessor :consecutive_signature_failures

      def healthy?
        error_message.empty?
      end

      def error_message
        return StatusMessages::NOT_ATTEMPTED unless fetch_attempted?
        return StatusMessages::MISSING       unless metadata_received?
        return StatusMessages::CERT_INVALID  unless idp_cert_valid?
        ''
      end

      private

      def fetch_attempted?
        SettingsService.fetch_attempted == true
      end

      def metadata_received?
        # guard against actually going and retrieving SAML metadata within the check itself
        return false unless fetch_attempted?
        SettingsService.merged_saml_settings&.idp_sso_target_url&.blank? == false
      end

      def idp_cert_valid?
        return false unless fetch_attempted? && metadata_received?
        begin
          formatted_cert = OneLogin::RubySaml::Utils.format_cert(SettingsService.merged_saml_settings&.idp_cert)
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
