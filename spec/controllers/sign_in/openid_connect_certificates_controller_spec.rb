# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::OpenidConnectCertificatesController, type: :controller do
  describe 'GET index' do
    subject { get(:index) }

    let(:public_key_jwk) { JWT::JWK.new(public_key, { alg: 'RS256', use: 'sig' }).export }
    let(:public_key) { OpenSSL::PKey::RSA.new(File.read(IdentitySettings.sign_in.jwt_encode_key)).public_key }
    let(:old_encode_key_setting) { nil }
    let(:expected_status) { :ok }

    before { IdentitySettings.sign_in.jwt_old_encode_key = old_encode_key_setting }

    context 'without an old Sign in Service access token encode setting' do
      let(:expected_public_key_jwks) { { keys: [public_key_jwk] } }

      it 'renders the current public key' do
        expect(JSON.parse(subject.body)).to eq(expected_public_key_jwks.as_json)
      end
    end

    context 'with an old Sign in Service access token encode setting' do
      let(:expected_public_key_jwks) { { keys: [public_key_jwk, old_public_key_jwk] } }
      let(:old_public_key_jwk) { JWT::JWK.new(old_public_key, { alg: 'RS256', use: 'sig' }).export }
      let(:old_public_key) { OpenSSL::PKey::RSA.new(File.read(IdentitySettings.sign_in.jwt_old_encode_key)) }
      let(:old_encode_key_setting) do
        IdentitySettings.sign_in.jwt_old_encode_key || IdentitySettings.sign_in.jwt_encode_key
      end

      it 'renders the current & previous public keys' do
        expect(JSON.parse(subject.body)).to eq(expected_public_key_jwks.as_json)
      end
    end

    it 'returns ok status' do
      expect(subject).to have_http_status(expected_status)
    end
  end
end
