# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::OpenidConnectCertificatesPresenter do
  describe '#perform' do
    subject { SignIn::OpenidConnectCertificatesPresenter.new.perform }

    let(:public_key_jwks) { { keys: [public_key_jwk] } }
    let(:public_key_jwk) {  JWT::JWK.new(public_key, { alg: 'RS256', use: 'sig' }).export }
    let(:public_key) { OpenSSL::PKey::RSA.new(File.read(Settings.sign_in.jwt_encode_key)).public_key }

    it 'returns JWK representation of sign in service access token encode key' do
      expect(subject).to eq(public_key_jwks)
    end
  end
end
