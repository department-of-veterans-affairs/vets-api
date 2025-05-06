# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::AccessTokenJwtDecoder do
  describe '#perform' do
    subject do
      SignIn::AccessTokenJwtDecoder.new(access_token_jwt:).perform(with_validation:)
    end

    let(:access_token_jwt) { SignIn::AccessTokenJwtEncoder.new(access_token:).perform }
    let(:access_token) { create(:access_token) }
    let(:with_validation) { true }
    let(:client_config) { create(:client_config) }
    let(:client_id) { client_config.client_id }

    context 'when access token jwt is expired' do
      let(:access_token_jwt) { SignIn::AccessTokenJwtEncoder.new(access_token:).perform }
      let(:access_token) { create(:access_token, expiration_time: 1.day.ago) }

      context 'and jwt validation is enabled' do
        let(:expected_error) { SignIn::Errors::AccessTokenExpiredError }
        let(:expected_error_message) { 'Access token has expired' }

        it 'returns an access token expired error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'and jwt validation is disabled' do
        let(:with_validation) { false }

        before do
          allow(SignIn::AccessToken).to receive(:new).and_return(access_token)
        end

        it 'returns the decoded access token' do
          expect(subject).to eq access_token
        end
      end
    end

    context 'when access token jwt is encoded with a different signature than expected' do
      let(:access_token_jwt) do
        JWT.encode(
          jwt_payload,
          OpenSSL::PKey::RSA.new(2048),
          SignIn::Constants::AccessToken::JWT_ENCODE_ALGORITHM
        )
      end

      let(:jwt_payload) do
        {
          iss: SignIn::Constants::AccessToken::ISSUER,
          aud: client_config.access_token_audience,
          client_id:,
          jti: SecureRandom.hex,
          sub: access_token.user_uuid,
          exp: access_token.expiration_time.to_i,
          iat: access_token.created_time.to_i,
          session_handle: access_token.session_handle,
          refresh_token_hash: access_token.refresh_token_hash,
          parent_refresh_token_hash: access_token.parent_refresh_token_hash,
          anti_csrf_token: access_token.anti_csrf_token,
          last_regeneration_time: access_token.last_regeneration_time.to_i,
          version: access_token.version
        }
      end

      context 'and jwt validation is enabled' do
        let(:expected_error) { SignIn::Errors::AccessTokenSignatureMismatchError }
        let(:expected_error_message) { 'Access token body does not match signature' }

        it 'returns an access token signature mismatch error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'and jwt validation is disabled' do
        let(:with_validation) { false }

        before do
          allow(SignIn::AccessToken).to receive(:new).and_return(access_token)
        end

        it 'returns the decoded access token' do
          expect(subject).to eq access_token
        end
      end
    end

    context 'when access token jwt is malformed' do
      let(:access_token_jwt) { 'some-messed-up-jwt' }
      let(:expected_error) { SignIn::Errors::AccessTokenMalformedJWTError }
      let(:expected_error_message) { 'Access token JWT is malformed' }

      it 'raises an access token malformed jwt error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when access token jwt is valid' do
      it 'returns an access token with expected attributes' do
        decoded_access_token = subject
        expect(decoded_access_token.session_handle).to eq(access_token.session_handle)
        expect(decoded_access_token.user_uuid).to eq(access_token.user_uuid)
        expect(decoded_access_token.client_id).to eq(access_token.client_id)
        expect(decoded_access_token.refresh_token_hash).to eq(access_token.refresh_token_hash)
        expect(decoded_access_token.anti_csrf_token).to eq(access_token.anti_csrf_token)
        expect(decoded_access_token.last_regeneration_time)
          .to eq(Time.zone.at(access_token.last_regeneration_time.to_i))
        expect(decoded_access_token.parent_refresh_token_hash).to eq(access_token.parent_refresh_token_hash)
        expect(decoded_access_token.version).to eq(access_token.version)
        expect(decoded_access_token.expiration_time).to eq(Time.zone.at(access_token.expiration_time.to_i))
        expect(decoded_access_token.created_time).to eq(Time.zone.at(access_token.created_time.to_i))
      end
    end
  end
end
