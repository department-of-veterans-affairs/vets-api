# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Keys endpoint', type: :request do
  include SchemaMatchers

  it 'returns an array of keys' do
    get '/services/veteran_verification/v0/keys'

    expect(response).to have_http_status(:ok)
    expect(response).to match_response_schema('veteran_verification/keys')
  end

  it 'the pem field is a valid base64url encoded public key' do
    original_pem = File.read(Settings.vet_verification.key_path)
    original_keypair = OpenSSL::PKey::RSA.new(original_pem)

    get '/services/veteran_verification/v0/keys'

    body = JSON.parse(response.body)
    pem = Base64.urlsafe_decode64(body['keys'].first['pem'])
    
    expect(pem).to eq(original_keypair.public_key.to_pem)
  end
end

