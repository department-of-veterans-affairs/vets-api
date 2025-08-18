# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::BaseAssertionValidator do
  subject(:validator) { dummy_validator_class.new }

  let(:dummy_validator_class) do
    Class.new(described_class) do
      def attributes_error_class
        StandardError
      end

      def signature_mismatch_error_class
        StandardError
      end

      def expired_error_class
        StandardError
      end

      def malformed_error_class
        StandardError
      end

      def active_certs
        @active_certs || []
      end

      attr_writer :active_certs
    end
  end

  describe 'abstract method enforcement' do
    subject(:base_validator) { described_class.new }

    it 'raises NotImplementedError for abstract methods' do
      %i[
        attributes_error_class
        signature_mismatch_error_class
        expired_error_class
        malformed_error_class
        active_certs
      ].each do |method_name|
        expect { base_validator.send(method_name) }
          .to raise_error(NotImplementedError), "expected #{method_name} to be abstract"
      end
    end
  end

  describe 'certificate validation behavior' do
    context 'when certificates are available' do
      let(:cert1) { create(:sign_in_certificate) }
      let(:cert2) { create(:sign_in_certificate) }

      it 'processes certificates without raising errors' do
        validator.active_certs = [cert1, cert2]

        expect { validator.send(:jwt_keyfinder, {}, {}) }.not_to raise_error
      end
    end

    context 'when no certificates are available' do
      it 'raises AssertionCertificateExpiredError for empty certificate array' do
        validator.active_certs = []

        expect { validator.send(:jwt_keyfinder, {}, {}) }
          .to raise_error(SignIn::Errors::AssertionCertificateExpiredError, 'Certificates are expired')
      end

      it 'raises AssertionCertificateExpiredError for nil certificates' do
        validator.active_certs = nil

        expect { validator.send(:jwt_keyfinder, {}, {}) }
          .to raise_error(SignIn::Errors::AssertionCertificateExpiredError, 'Certificates are expired')
      end
    end
  end
end
