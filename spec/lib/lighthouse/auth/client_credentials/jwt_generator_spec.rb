# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/auth/client_credentials/jwt_generator'

RSpec.describe Auth::ClientCredentials::JWTGenerator do
  let(:public_key) { OpenSSL::PKey::RSA.new(File.read('spec/support/certificates/lhdd-fake-public.pem')) }

  it 'generates a valid JWT token' do
    client_id = '1234567890'
    aud_claim_url = 'https://deptva-eval.okta.com/oauth2/1234567890/v1/token'
    key_location = 'spec/support/certificates/lhdd-fake-private.pem'

    encoded_token = Auth::ClientCredentials::JWTGenerator.generate_token(client_id, aud_claim_url, key_location)
    expect(encoded_token).not_to be_empty

    decoded_token = JWT.decode(encoded_token, public_key, true, { algorithm: 'RS256' })
    expect(token_valid?(decoded_token, client_id, aud_claim_url)).to be(true)
  end

  def token_valid?(token, client_id, aud_claim_url)
    token.first['iss'] == client_id &&
      token.first['sub'] == client_id &&
      token.first['aud'] == aud_claim_url &&
      token.first['iat'].present? &&
      token.first['exp'].present?
  end
end
