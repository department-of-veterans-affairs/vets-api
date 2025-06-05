# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::Certificate, type: :model do
  subject(:certificate) { create(:sign_in_certificate) }

  describe 'associations' do
    it { is_expected.to have_many(:config_certificates).dependent(:destroy) }
    it { is_expected.to have_many(:client_configs).through(:config_certificates) }
    it { is_expected.to have_many(:service_account_configs).through(:config_certificates) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:pem) }

    context 'when PEM is invalid' do
      subject(:certificate) { build(:sign_in_certificate, pem: 'not a valid pem') }

      it 'is not valid and adds X.509 error' do
        expect(certificate).not_to be_valid
        expect(certificate.errors[:pem]).to include('not a valid X.509 certificate')
      end
    end

    context 'when certificate is valid' do
      it { is_expected.to be_valid }
    end

    context 'when the certificate is expired' do
      subject(:certificate) { build(:sign_in_certificate, :expired) }

      it 'is not valid and adds expired error' do
        expect(certificate).not_to be_valid
        expect(certificate.errors[:pem]).to include('certificate is expired')
      end

      it '#expired? returns true' do
        expect(certificate.expired?).to be true
      end
    end

    context 'when the certificate is not yet valid' do
      subject(:certificate) { build(:sign_in_certificate, :not_yet_valid) }

      it 'is not valid and adds “not yet valid” error' do
        expect(certificate).not_to be_valid
        expect(certificate.errors[:pem]).to include('certificate is not yet valid')
      end
    end

    context 'when the certificate is self-signed' do
      subject(:certificate) { build(:sign_in_certificate, :self_signed) }

      it 'is not valid and adds self‑signed error' do
        expect(certificate).not_to be_valid
        expect(certificate.errors[:pem]).to include('certificate is self-signed')
      end
    end
  end

  describe 'delegations' do
    it { is_expected.to delegate_method(:not_before).to(:certificate) }
    it { is_expected.to delegate_method(:not_after).to(:certificate) }
    it { is_expected.to delegate_method(:subject).to(:certificate) }
    it { is_expected.to delegate_method(:issuer).to(:certificate) }
    it { is_expected.to delegate_method(:serial).to(:certificate) }
  end

  describe '#expired?' do
    context 'when the certificate is expired' do
      subject(:certificate) { build(:sign_in_certificate, :expired) }

      it 'returns true' do
        expect(certificate.expired?).to be true
      end

      context 'when the certificate is not expired' do
        subject(:certificate) { build(:sign_in_certificate) }

        it 'returns false' do
          expect(certificate.expired?).to be false
        end
      end
    end
  end
end
