# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::Certificate, type: :model do
  subject(:certificate) { build(:sign_in_certificate) }

  it { is_expected.to belong_to(:client_config).optional }
  it { is_expected.to belong_to(:service_account_config).optional }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:issuer) }
    it { is_expected.to validate_presence_of(:subject) }
    it { is_expected.to validate_presence_of(:serial) }
    it { is_expected.to validate_presence_of(:not_before) }
    it { is_expected.to validate_presence_of(:not_after) }
    it { is_expected.to validate_presence_of(:plaintext) }

    it 'does not allow expired certificates' do
      certificate.not_after = 1.day.ago
      expect(certificate).not_to be_valid
      expect(certificate.errors[:not_after]).to include('cannot be in the past')
    end

    it 'does not allow self-signed certificates' do
      certificate.issuer = certificate.subject
      expect(certificate).not_to be_valid
      expect(certificate.errors[:subject]).to include('cannot be the same as the issuer')
    end
  end

  describe '.from_plaintext' do
    let(:client_config) { create(:client_config) }

    context 'with a valid certificate' do
      let(:plaintext) { File.read('spec/fixtures/sign_in/sample_configuration_certificate.crt') }

      it 'returns a certificate' do
        record = described_class.from_plaintext(plaintext, client_config:)
        expect(record).to be_a(described_class)
        expect(record).to be_valid
      end
    end

    context 'with an empty certificate' do
      let(:plaintext) { '' }

      it 'returns false' do
        expect(described_class.from_plaintext(plaintext, client_config:)).to be_falsey
      end
    end

    context 'with an invalid certificate' do
      let(:plaintext) { SecureRandom.hex }

      it 'returns false' do
        expect(described_class.from_plaintext(plaintext, client_config:)).to be_falsey
      end
    end
  end

  describe '.expired' do
    let(:client_config) { create(:client_config) }
    let!(:expired_certificate) { create(:sign_in_certificate, :expired, client_config:) }

    before do
      create_list(:sign_in_certificate, 3, client_config:)
    end

    it 'returns certificates that are expired' do
      expect(SignIn::Certificate.expired).to contain_exactly(expired_certificate)
    end
  end

  describe '#expired?' do
    it 'returns true if the certificate is expired' do
      certificate.not_after = 1.day.ago
      expect(certificate.expired?).to be(true)
    end

    it 'returns false if the certificate is not expired' do
      certificate.not_after = 1.day.from_now
      expect(certificate.expired?).to be(false)
    end
  end

  describe '.expiring' do
    let(:client_config) { create(:client_config) }
    let!(:expiring_certificate) { create(:sign_in_certificate, not_after: 5.days.from_now, client_config:) }

    before do
      create_list(:sign_in_certificate, 3, client_config:)
    end

    it 'returns certificates that are expiring' do
      expect(SignIn::Certificate.expiring).to contain_exactly(expiring_certificate)
    end
  end

  describe '.self_signed' do
    let(:client_config) { create(:client_config) }
    let!(:self_signed_certificate) { create(:sign_in_certificate, :self_signed, client_config:) }

    before do
      create_list(:sign_in_certificate, 3, client_config:)
    end

    it 'returns certificates that are self-signed' do
      expect(SignIn::Certificate.self_signed).to contain_exactly(self_signed_certificate)
    end
  end

  describe '#self_signed?' do
    it 'returns true if the certificate is self-signed' do
      certificate.issuer = certificate.subject
      expect(certificate.self_signed?).to be(true)
    end

    it 'returns false if the certificate is not self-signed' do
      certificate.issuer = 'some-other-subject'
      expect(certificate.self_signed?).to be(false)
    end
  end
end
