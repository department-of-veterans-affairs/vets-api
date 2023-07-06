# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ServiceAccountAccessTokenJwtEncoder do
  describe '#perform' do
    subject do
      SignIn::ServiceAccountAccessTokenJwtEncoder.new(decoded_service_account_assertion:).perform
    end

    let(:decoded_service_account_assertion) do
      OpenStruct.new({ sub:, scopes:, service_account_id: })
    end
    let(:service_account_config) { create(:service_account_config) }
    let(:service_account_id) { service_account_config.service_account_id }
    let(:scopes) { service_account_config.scopes }
    let(:expected_audience) { service_account_config.access_token_audience }
    let(:sub) { 'some-user-email@va.gov' }
    let(:public_key) { OpenSSL::PKey::RSA.new(File.read(Settings.sign_in.jwt_encode_key)).public_key }
    let(:algorithm) { SignIn::Constants::ServiceAccountAccessToken::JWT_ENCODE_ALGORITHM }

    context 'without a Service Account configuration' do
      let(:service_account_config) { nil }
      let(:service_account_id) { SecureRandom.hex }
      let(:scopes) { ['first-scope, second-scope'] }
      let(:expected_audience) { 'some-expected-audience' }
      let(:expected_error) { SignIn::Errors::ServiceAccountConfigNotFound }
      let(:expected_error_message) { 'Service account config not found' }

      it 'raises a ServiceAccountConfig not found error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'with a Service Account configuration' do
      it 'returns a JWT that can be validated with the SiS public key and has expected values' do
        decoded_jwt = OpenStruct.new(
          JWT.decode(subject, public_key, true, { verify_expiration: true, algorithm: }).first
        )
        expect(decoded_jwt.sub).to eq(sub)
        expect(decoded_jwt.scopes).to eq(scopes)
        expect(decoded_jwt.aud).to eq(expected_audience)
      end
    end
  end
end
