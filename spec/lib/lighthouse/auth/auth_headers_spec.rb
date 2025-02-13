require 'rails_helper'

RSpec.describe EVSS::AuthHeaders do
  let(:user) { build(:user) }

  describe 'class delegation' do
    context 'when lighthouse_base_headers is enabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:lighthouse_base_headers)
          .and_return(true)
      end

      it 'creates an instance delegating to Lighthouse::BaseHeaders' do
        auth_headers = described_class.new(user)
        expect(auth_headers.instance_variable_get(:@delegate)).to be_a(Lighthouse::BaseHeaders)
      end
    end

    context 'when lighthouse_base_headers is disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:lighthouse_base_headers)
          .and_return(false)
      end

      it 'creates an instance delegating to EVSS::BaseHeaders' do
        auth_headers = described_class.new(user)
        expect(auth_headers.instance_variable_get(:@delegate)).to be_a(EVSS::BaseHeaders)
      end
    end

    context 'when Flipper check raises an error' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:lighthouse_base_headers)
          .and_raise(StandardError.new('Flipper error'))
      end

      it 'defaults to EVSS::BaseHeaders' do
        auth_headers = described_class.new(user)
        expect(auth_headers.instance_variable_get(:@delegate)).to be_a(EVSS::BaseHeaders)
      end

      it 'logs a warning' do
        expect(Rails.logger).to receive(:warn)
          .with(/Error checking Flipper flag: Flipper error/)
        described_class.new(user)
      end
    end
  end

  describe '#to_h' do
    subject(:auth_headers) { described_class.new(user) }

    it 'includes required headers' do
      headers = auth_headers.to_h
      expect(headers).to include(
        'va_eauth_csid' => 'DSLogon',
        'va_eauth_authenticationmethod' => 'DSLogon',
        'va_eauth_pnidtype' => 'SSN'
      )
    end
  end
end