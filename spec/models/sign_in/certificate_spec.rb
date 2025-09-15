# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::Certificate, type: :model do
  subject(:certificate) { build(:sign_in_certificate) }

  describe 'associations' do
    it { is_expected.to have_many(:config_certificates).dependent(:destroy) }
    it { is_expected.to have_many(:client_configs).through(:config_certificates) }
    it { is_expected.to have_many(:service_account_configs).through(:config_certificates) }
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_certificate) { create(:sign_in_certificate) }
      let!(:expiring_soon_certificate) { create(:sign_in_certificate, :expiring_soon) }
      let(:expired_certificate) { build(:sign_in_certificate, :expired) }

      before do
        expired_certificate.save(validate: false)
      end

      it 'returns only active certificates' do
        expect(SignIn::Certificate.active).to include(active_certificate)
      end

      it 'returns expiring soon certificates' do
        expect(SignIn::Certificate.active).to include(expiring_soon_certificate)
      end
    end

    describe '.expired' do
      let(:expired_certificate) { build(:sign_in_certificate, :expired) }
      let(:not_expired_certificate) { create(:sign_in_certificate) }

      before do
        expired_certificate.save(validate: false)
      end

      it 'returns only expired certificates' do
        expect(SignIn::Certificate.expired).to contain_exactly(expired_certificate)
      end
    end

    describe '.expiring_soon' do
      let!(:expiring_soon_certificate) { create(:sign_in_certificate, :expiring_soon) }
      let!(:not_expiring_certificate) { create(:sign_in_certificate, not_before: 61.days.ago) }

      it 'returns only certificates expiring within 60 days' do
        expect(SignIn::Certificate.expiring_soon).to contain_exactly(expiring_soon_certificate)
      end
    end
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
        expect(certificate.errors[:pem]).to include('X.509 certificate is expired')
      end

      it '#expired? returns true' do
        expect(certificate.expired?).to be true
      end
    end

    context 'when the certificate is not yet valid' do
      subject(:certificate) { build(:sign_in_certificate, :not_yet_valid) }

      it 'is not valid and adds “not yet valid” error' do
        expect(certificate).not_to be_valid
        expect(certificate.errors[:pem]).to include('X.509 certificate is not yet valid')
      end
    end

    context 'when the certificate is self-signed' do
      subject(:certificate) { build(:sign_in_certificate, :self_signed) }

      it 'is not valid and adds self‑signed error' do
        expect(certificate).not_to be_valid
        expect(certificate.errors[:pem]).to include('X.509 certificate is self-signed')
      end
    end
  end

  describe 'delegations' do
    it { is_expected.to delegate_method(:not_before).to(:x509) }
    it { is_expected.to delegate_method(:not_after).to(:x509) }
    it { is_expected.to delegate_method(:subject).to(:x509) }
    it { is_expected.to delegate_method(:issuer).to(:x509) }
    it { is_expected.to delegate_method(:serial).to(:x509) }
  end

  describe '#certificate' do
    context 'when PEM is valid' do
      it 'returns an OpenSSL::X509::Certificate object' do
        expect(certificate.x509).to be_a(OpenSSL::X509::Certificate)
      end
    end

    context 'when PEM is invalid' do
      subject(:certificate) { build(:sign_in_certificate, pem: 'not a valid pem') }

      it 'returns nil' do
        expect(certificate.x509).to be_nil
      end
    end
  end

  describe '#certificate?' do
    context 'when certificate is valid' do
      it 'returns true' do
        expect(certificate.x509?).to be true
      end
    end

    context 'when certificate is invalid' do
      subject(:certificate) { build(:sign_in_certificate, pem: 'not a valid pem') }

      it 'returns false' do
        expect(certificate.x509?).to be false
      end
    end
  end

  describe '#status' do
    context 'when certificate is active' do
      subject(:certificate) { build(:sign_in_certificate) }

      it 'returns "active"' do
        expect(certificate.status).to eq('active')
      end
    end

    context 'when certificate is expired' do
      subject(:certificate) { build(:sign_in_certificate, :expired) }

      it 'returns "expired"' do
        expect(certificate.status).to eq('expired')
      end
    end

    context 'when certificate is expiring' do
      subject(:certificate) { build(:sign_in_certificate, :expiring_soon) }

      it 'returns "expiring"' do
        expect(certificate.status).to eq('expiring_soon')
      end
    end
  end

  describe '#public_key' do
    context 'when certificate is valid' do
      it 'returns the public key of the certificate' do
        expect(certificate.public_key).to be_a(OpenSSL::PKey::RSA)
      end
    end

    context 'when certificate is invalid' do
      subject(:certificate) { build(:sign_in_certificate, pem: 'not a valid pem') }

      it 'returns nil' do
        expect(certificate.public_key).to be_nil
      end
    end
  end

  describe '#active?' do
    context 'when the certificate is active' do
      subject(:certificate) { build(:sign_in_certificate) }

      it 'returns true' do
        expect(certificate.active?).to be true
      end

      context 'when the certificate is expired' do
        subject(:certificate) { build(:sign_in_certificate, :expired) }

        it 'returns false' do
          expect(certificate.active?).to be false
        end
      end
    end
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

  describe '#expiring_soon?' do
    context 'when the certificate is expiring within 60 days' do
      subject(:certificate) { build(:sign_in_certificate, :expiring_soon) }

      it 'returns true' do
        expect(certificate.expiring_soon?).to be true
      end

      context 'when the certificate is not expiring' do
        subject(:certificate) { build(:sign_in_certificate) }

        it 'returns false' do
          expect(certificate.expiring_soon?).to be false
        end
      end
    end
  end
end
