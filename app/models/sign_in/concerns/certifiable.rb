# frozen_string_literal: true

module SignIn
  module Concerns
    module Certifiable
      extend ActiveSupport::Concern

      def assertion_public_keys
        @assertion_public_keys ||= certificate_objects.map(&:public_key)
      end

      def expired_certificates
        @expired_certificates ||= certificate_objects.select do |certificate|
          certificate.not_after < Time.zone.now
        end
      end

      def expiring_certificates
        @expiring_certificates ||= certificate_objects.select do |certificate|
          certificate.not_after < 60.days.from_now
        end
      end

      def self_signed_certificates
        @self_signed_certificates ||= certificate_objects.select do |certificate|
          certificate.issuer == certificate.subject
        end
      end

      private

      def certificate_objects
        @certificate_objects ||= load_certificate_objects
      end

      def load_certificate_objects
        return [] if certificates.blank?

        certificates.compact.map do |certificate|
          OpenSSL::X509::Certificate.new(certificate)
        end
      end
    end
  end
end
