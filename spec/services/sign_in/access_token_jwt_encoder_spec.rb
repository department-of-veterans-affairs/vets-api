# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::AccessTokenJwtEncoder do
  describe '#perform' do
    subject { SignIn::AccessTokenJwtEncoder.new(access_token: access_token).perform }

    let(:access_token) { create(:access_token) }

    context 'when input object is an access token' do
      let(:expected_sub) { access_token.user_uuid }
      let(:expected_iss) { SignIn::Constants::AccessToken::ISSUER }
      let(:expected_aud) { SignIn::Constants::AccessToken::MOBILE_AUDIENCE }
      let(:expected_client_id) { SignIn::Constants::AccessToken::MOBILE_CLIENT_ID }
      let(:expected_exp) { access_token.expiration_time.to_i }
      let(:expected_iat) { access_token.created_time.to_i }
      let(:expected_session_handle) { access_token.session_handle }
      let(:expected_refresh_token_hash) { access_token.refresh_token_hash }
      let(:expected_parent_refresh_token_hash) { access_token.parent_refresh_token_hash }
      let(:expected_anti_csrf_token) { access_token.anti_csrf_token }
      let(:expected_last_regeneration_time) { access_token.last_regeneration_time.to_i }
      let(:expected_version) { access_token.version }
      let(:expected_jti) { 'some-expected-jti' }

      before do
        allow(SecureRandom).to receive(:hex).and_return(expected_jti)
      end

      it 'returns an encoded jwt with expected parameters' do
        decoded_jwt = OpenStruct.new(JWT.decode(subject, false, nil).first)
        expect(decoded_jwt.sub).to eq expected_sub
        expect(decoded_jwt.iss).to eq expected_iss
        expect(decoded_jwt.aud).to eq expected_aud
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
      end
    end
  end
end
