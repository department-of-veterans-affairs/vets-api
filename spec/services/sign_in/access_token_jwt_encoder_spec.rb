# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::AccessTokenJwtEncoder do
  describe '#perform' do
    subject { SignIn::AccessTokenJwtEncoder.new(access_token:).perform }

    let(:access_token) { create(:access_token, client_id:) }
    let(:client_id) { client_config.client_id }
    let(:client_config) { create(:client_config, access_token_attributes:) }
    let(:access_token_attributes) { [] }

    context 'when input object is an access token' do
      let(:expected_sub) { access_token.user_uuid }
      let(:expected_iss) { SignIn::Constants::AccessToken::ISSUER }
      let(:expected_client_id) { access_token.client_id }
      let(:expected_exp) { access_token.expiration_time.to_i }
      let(:expected_iat) { access_token.created_time.to_i }
      let(:expected_session_handle) { access_token.session_handle }
      let(:expected_refresh_token_hash) { access_token.refresh_token_hash }
      let(:expected_parent_refresh_token_hash) { access_token.parent_refresh_token_hash }
      let(:expected_anti_csrf_token) { access_token.anti_csrf_token }
      let(:expected_last_regeneration_time) { access_token.last_regeneration_time.to_i }
      let(:expected_version) { access_token.version }
      let(:expected_jti) { access_token.uuid }
      let(:expected_aud) { access_token.audience }

      before do
        allow(SecureRandom).to receive(:hex).and_return(expected_jti)
      end

      it 'returns an encoded jwt with expected parameters' do
        decoded_jwt = OpenStruct.new(JWT.decode(subject, false, nil).first)
        expect(decoded_jwt.sub).to eq expected_sub
        expect(decoded_jwt.iss).to eq expected_iss
        expect(decoded_jwt.client_id).to eq expected_client_id
        expect(decoded_jwt.exp).to eq expected_exp
        expect(decoded_jwt.iat).to eq expected_iat
        expect(decoded_jwt.session_handle).to eq expected_session_handle
        expect(decoded_jwt.refresh_token_hash).to eq expected_refresh_token_hash
        expect(decoded_jwt.parent_refresh_token_hash).to eq expected_parent_refresh_token_hash
        expect(decoded_jwt.anti_csrf_token).to eq expected_anti_csrf_token
        expect(decoded_jwt.last_regeneration_time).to eq expected_last_regeneration_time
        expect(decoded_jwt.version).to eq expected_version
        expect(decoded_jwt.jti).to eq expected_jti
        expect(decoded_jwt.aud).to eq expected_aud
      end

      context 'expected user_attributes on encoded access token' do
        context 'when there are no user attributes on the correlated ClientConfig access_token_attributes' do
          it 'does not include user attributes on the encoded access token' do
            decoded_jwt = OpenStruct.new(JWT.decode(subject, false, nil).first)
            expect(decoded_jwt.user_attributes).to eq({})
          end
        end

        context 'when there are one or more user attributes on the correlated ClientConfig access_token_attributes' do
          let(:access_token_attributes) { %w[first_name last_name] }
          let(:expected_first_name) { access_token.user_attributes['first_name'] }
          let(:expected_last_name) { access_token.user_attributes['last_name'] }

          it 'includes those attributes on the encoded access token' do
            decoded_jwt = OpenStruct.new(JWT.decode(subject, false, nil).first)
            serialized_attributes = decoded_jwt.user_attributes
            expect(serialized_attributes['first_name']).to eq(expected_first_name)
            expect(serialized_attributes['last_name']).to eq(expected_last_name)
            expect(serialized_attributes['email']).to be_nil
          end
        end
      end
    end
  end
end
