# frozen_string_literal: true

module SignIn
  module Concerns
    module Certifiable
      extend ActiveSupport::Concern

      def assertion_public_keys
        @assertion_public_keys ||= certificate_objects.map(&:public_key)
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
