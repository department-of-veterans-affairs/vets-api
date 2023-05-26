# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::OpenidConnectCertificatesController, type: :controller do
  describe 'GET index' do
    subject { get(:index) }

    let(:public_key_jwks) { { keys: [public_key_jwk] } }
    let(:public_key_jwk) {  JWT::JWK.new(public_key, { alg: 'RS256', use: 'sig' }).export }
    let(:public_key) { OpenSSL::PKey::RSA.new(File.read(Settings.sign_in.jwt_encode_key)).public_key }
    let(:expected_status) { :ok }

    it 'renders hash of public key jwks' do
      expect(JSON.parse(subject.body)).to eq(public_key_jwks.as_json)
    end

    it 'returns ok status' do
      expect(subject).to have_http_status(expected_status)
    end
  end
end
