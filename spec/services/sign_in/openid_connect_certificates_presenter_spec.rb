# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::OpenidConnectCertificatesPresenter do
  describe '#perform' do
    subject { SignIn::OpenidConnectCertificatesPresenter.new.perform }

    let(:public_key_jwk) { JWT::JWK.new(public_key, { alg: 'RS256', use: 'sig' }).export }
    let(:public_key) { OpenSSL::PKey::RSA.new(File.read(Settings.sign_in.jwt_encode_key)).public_key }

    before { allow(Settings.sign_in).to receive(:jwt_old_encode_key).and_return(old_encode_key_setting) }

    shared_examples 'certificates return' do
      it 'returns a JWK representation of Sign in Service public keys' do
        expect(subject).to eq(expected_public_keys_jwks)
      end
    end

    context 'without an old Sign in Service access token encode setting' do
      let(:expected_public_keys_jwks) { { keys: [public_key_jwk] } }
      let(:old_encode_key_setting) { nil }

      it_behaves_like 'certificates return'
    end

    context 'with an old Sign in Service access token encode setting' do
      let(:expected_public_keys_jwks) { { keys: [public_key_jwk, old_public_key_jwk] } }
      let(:old_public_key_jwk) { JWT::JWK.new(old_public_key, { alg: 'RS256', use: 'sig' }).export }
      let(:old_public_key) { OpenSSL::PKey::RSA.new(File.read(Settings.sign_in.jwt_old_encode_key)) }
      let(:old_encode_key_setting) { Settings.sign_in.jwt_encode_key }

      it_behaves_like 'certificates return'
    end
  end
end
