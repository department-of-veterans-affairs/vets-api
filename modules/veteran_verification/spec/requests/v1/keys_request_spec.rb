# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Keys endpoint', type: :request do
  include SchemaMatchers

  let(:original_pem) { File.read(Settings.vet_verification.key_path) }
  let(:original_keypair) { OpenSSL::PKey::RSA.new(original_pem) }

  it 'returns an array of keys' do
    get '/services/veteran_verification/v1/keys'

    expect(response).to have_http_status(:ok)
    expect(response).to match_response_schema('veteran_verification/keys')
  end

  it 'returns an array of keys when camel-inflected' do
    get '/services/veteran_verification/v1/keys', headers: { 'X-Key-Inflection' => 'camel' }

    expect(response).to have_http_status(:ok)
    expect(response).to match_camelized_response_schema('veteran_verification/keys')
  end

  it 'the pem field is a valid base64url encoded public key' do
    get '/services/veteran_verification/v1/keys'

    body = JSON.parse(response.body)
    pem = body['keys'].first['pem']

    expect(pem).to eq(original_keypair.public_key.to_pem)
  end

  it 'returns the exponent and modulus as Base64UrlUInt encoded per rfc7518' do
    get '/services/veteran_verification/v1/keys'

    key = JSON.parse(response.body)['keys'].first

    # Decodes the Base64Url encoded big-endian representation of the integer
    e = Base64.urlsafe_decode64(key['e']).unpack1('B*').to_i(2)
    n = Base64.urlsafe_decode64(key['n']).unpack1('B*').to_i(2)

    expect(e).to eq(original_keypair.public_key.e.to_i)
    expect(n).to eq(original_keypair.public_key.n.to_i)
  end
end
