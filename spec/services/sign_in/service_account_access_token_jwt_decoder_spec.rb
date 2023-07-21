# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ServiceAccountAccessTokenJwtDecoder do
  describe '#perform' do
    subject do
      SignIn::ServiceAccountAccessTokenJwtDecoder.new(service_account_access_token_jwt:).perform(with_validation:)
    end

    let(:with_validation) { true }
    let(:service_account_access_token_jwt) do
      SignIn::ServiceAccountAccessTokenJwtEncoder.new(service_account_access_token:).perform
    end
    let(:service_account_access_token) { create(:service_account_access_token, expiration_time:) }
    let(:expiration_time) { 1.day.since }
    let(:service_account_id) { service_account_config.service_account_id }
    let(:service_account_config) { create(:service_account_config) }

    context 'when service account access token jwt is expired' do
      let(:expiration_time) { 1.day.ago }

      context 'and jwt validation is enabled' do
        let(:expected_error) { SignIn::Errors::AccessTokenExpiredError }
        let(:expected_error_message) { 'Service Account access token has expired' }

        it 'returns an access token expired error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'and jwt validation is disabled' do
        let(:with_validation) { false }

        before do
          allow(SignIn::ServiceAccountAccessToken).to receive(:new).and_return(service_account_access_token)
        end

        it 'returns the decoded service account access token' do
          expect(subject).to eq(service_account_access_token)
        end
      end
    end

    context 'when service account access token jwt is encoded with a different signature than expected' do
      let(:service_account_access_token_jwt) do
        JWT.encode(
          jwt_payload,
          OpenSSL::PKey::RSA.new(2048),
          SignIn::Constants::AccessToken::JWT_ENCODE_ALGORITHM
        )
      end

      let(:jwt_payload) do
        {
          iss: SignIn::Constants::AccessToken::ISSUER,
          aud: service_account_access_token.audience,
          jti: service_account_access_token.uuid,
          sub: service_account_access_token.user_identifier,
          exp: service_account_access_token.expiration_time.to_i,
          iat: service_account_access_token.created_time.to_i,
          version: service_account_access_token.version,
          scopes: service_account_access_token.scopes,
          service_account_id: service_account_access_token.service_account_id
        }
      end

      context 'and jwt validation is enabled' do
        let(:expected_error) { SignIn::Errors::AccessTokenSignatureMismatchError }
        let(:expected_error_message) { 'Service Account access token body does not match signature' }

        it 'returns an access token signature mismatch error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'and jwt validation is disabled' do
        let(:with_validation) { false }

        before do
          allow(SignIn::ServiceAccountAccessToken).to receive(:new).and_return(service_account_access_token)
        end

        it 'returns the decoded service account access token' do
          expect(subject).to eq(service_account_access_token)
        end
      end
    end

    context 'when service account access token jwt is malformed' do
      let(:service_account_access_token_jwt) { 'some-messed-up-jwt' }
      let(:expected_error) { SignIn::Errors::AccessTokenMalformedJWTError }
      let(:expected_error_message) { 'Service Account access token JWT is malformed' }

      it 'raises an access token malformed jwt error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when service account access token jwt is valid' do
      it 'returns an access token with expected attributes' do
        decoded_access_token = subject
        expect(decoded_access_token.audience).to eq(service_account_access_token.audience)
        expect(decoded_access_token.uuid).to eq(service_account_access_token.uuid)
        expect(decoded_access_token.user_identifier).to eq(service_account_access_token.user_identifier)
        expect(decoded_access_token.scopes).to eq(service_account_access_token.scopes)
        expect(decoded_access_token.service_account_id).to eq(service_account_access_token.service_account_id)
        expect(decoded_access_token.version).to eq(service_account_access_token.version)
        expect(decoded_access_token.expiration_time)
          .to eq(Time.zone.at(service_account_access_token.expiration_time.to_i))
        expect(decoded_access_token.created_time).to eq(Time.zone.at(service_account_access_token.created_time.to_i))
      end
    end
  end
end
