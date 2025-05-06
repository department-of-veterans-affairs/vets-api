# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ServiceAccountAccessTokenJwtEncoder do
  describe '#perform' do
    subject { SignIn::ServiceAccountAccessTokenJwtEncoder.new(service_account_access_token:).perform }

    let(:service_account_access_token) { create(:service_account_access_token) }

    context 'when input object is a service account access token' do
      let(:expected_iss) { SignIn::Constants::ServiceAccountAccessToken::ISSUER }
      let(:expected_aud) { service_account_access_token.audience }
      let(:expected_jti) { service_account_access_token.uuid }
      let(:expected_sub) { service_account_access_token.user_identifier }
      let(:expected_exp) { service_account_access_token.expiration_time.to_i }
      let(:expected_iat) { service_account_access_token.created_time.to_i }
      let(:expected_nbf) { service_account_access_token.created_time.to_i }
      let(:expected_version) { service_account_access_token.version }
      let(:expected_scopes) { service_account_access_token.scopes }
      let(:expected_service_account_id) { service_account_access_token.service_account_id }
      let(:expected_user_attributes) { service_account_access_token.user_attributes }

      before do
        allow(SecureRandom).to receive(:hex).and_return(expected_jti)
      end

      it 'returns an encoded jwt with expected parameters' do
        decoded_jwt = OpenStruct.new(JWT.decode(subject, false, nil).first)
        expect(decoded_jwt.iss).to eq expected_iss
        expect(decoded_jwt.aud).to eq expected_aud
        expect(decoded_jwt.jti).to eq expected_jti
        expect(decoded_jwt.sub).to eq expected_sub
        expect(decoded_jwt.exp).to eq expected_exp
        expect(decoded_jwt.iat).to eq expected_iat
        expect(decoded_jwt.nbf).to eq expected_nbf
        expect(decoded_jwt.version).to eq expected_version
        expect(decoded_jwt.scopes).to eq expected_scopes
        expect(decoded_jwt.service_account_id).to eq expected_service_account_id
        expect(decoded_jwt.user_attributes).to eq expected_user_attributes
      end

      context 'with optional user_attributes claim' do
        let(:service_account_access_token) { create(:service_account_access_token, user_attributes:) }
        let(:user_attributes) { { 'foo' => 'bar' } }

        it 'returns an encoded jwt with expected parameters' do
          decoded_jwt = OpenStruct.new(JWT.decode(subject, false, nil).first)
          expect(decoded_jwt.user_attributes).to eq expected_user_attributes
        end
      end
    end
  end
end
