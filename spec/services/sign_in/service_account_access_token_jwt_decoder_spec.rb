# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ServiceAccountAccessTokenJwtDecoder do
  describe '#perform' do
    subject do
      SignIn::ServiceAccountAccessTokenJwtDecoder.new(service_account_access_token_jwt:).perform
    end

    let(:service_account_access_token_jwt) do
      SignIn::ServiceAccountAccessTokenJwtEncoder.new(decoded_service_account_assertion:).perform
    end
    let(:decoded_service_account_assertion) do
      OpenStruct.new({ sub:, scopes:, service_account_id: })
    end
    let(:service_account_id) { service_account_config.service_account_id }
    let(:service_account_config) { create(:service_account_config) }
    let(:scheme) { Settings.vsp_environment == 'localhost' ? 'http://' : 'https://' }
    let(:iss) { "#{scheme}#{Settings.hostname}/#{SignIn::Constants::ServiceAccountAccessToken::ISSUER}" }
    let(:iat) { Time.now.to_i }
    let(:sub) { 'some-user-email@va.gov' }
    let(:aud) { service_account_config.access_token_audience }
    let(:scopes) { service_account_config.scopes }

    before do
      allow_any_instance_of(SignIn::ServiceAccountAccessTokenJwtEncoder).to receive(:issued_at_time).and_return(iat)
    end

    context 'and state payload jwt is an expired JWT' do
      let(:iat) { Time.new(2013, 1, 3).to_i }
      let(:expected_error) { SignIn::Errors::AccessTokenExpiredError }
      let(:expected_error_message) { 'Service Account access token has expired' }

      it 'renders Access Token Expired error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when state payload jwt is encoded with a different signature than expected' do
      let(:service_account_access_token_payload) do
        {
          iss:,
          aud:,
          jti: SecureRandom.hex,
          sub:,
          iat: Time.now.to_i,
          exp: Time.now.to_i + service_account_config.access_token_duration.to_i,
          version: SignIn::Constants::ServiceAccountAccessToken::CURRENT_VERSION,
          scopes:
        }
      end
      let(:service_account_access_token_jwt) do
        JWT.encode(service_account_access_token_payload,
                   OpenSSL::PKey::RSA.new(2048),
                   SignIn::Constants::Auth::JWT_ENCODE_ALGORITHM)
      end
      let(:expected_error) { SignIn::Errors::AccessTokenSignatureMismatchError }
      let(:expected_error_message) { 'Service Account access token body does not match signature' }

      it 'returns a JWT signature mismatch error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when service_account_access_token_jwt is malformed' do
      let(:service_account_access_token_jwt) { 'some-messed-up-jwt' }
      let(:expected_error) { SignIn::Errors::AccessTokenMalformedJWTError }
      let(:expected_error_message) { 'Service Account access token JWT is malformed' }

      it 'raises a malformed jwt error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when service_account_access_token_jwt is valid' do
      it 'returns a State Payload with expected attributes' do
        decoded_state_payload = subject
        expect(decoded_state_payload.iss).to eq(iss)
        expect(decoded_state_payload.aud).to eq(aud)
        expect(decoded_state_payload.sub).to eq(sub)
        expect(decoded_state_payload.scopes).to eq(scopes)
      end
    end
  end
end
