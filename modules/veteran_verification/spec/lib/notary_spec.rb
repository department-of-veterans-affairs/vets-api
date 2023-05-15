# frozen_string_literal: true

require 'rails_helper'
require 'notary'

RSpec.describe VeteranVerification::Notary do
  let(:keypair_path) do
    "#{VeteranVerification::Engine.root}/spec/fixtures/verification_test.pem"
  end

  it 'signs an arbitrary payload for verification with the correct public key' do
    to_sign = { type: 'salmon', habitat: 'river' }

    notary = VeteranVerification::Notary.new(keypair_path)
    signed = notary.sign(to_sign)

    payload = JWT.decode(signed, notary.public_key, true, algorithm: 'RS256').first

    expect(payload['type']).to eq('salmon')
    expect(payload['habitat']).to eq('river')
  end

  it 'includes a key id (kid) to identify which public key can verify the payload' do
    to_sign = { type: 'arctic fox', habitat: 'tundra' }

    notary = VeteranVerification::Notary.new(keypair_path)
    signed = notary.sign(to_sign)

    _, headers = JWT.decode(signed, notary.public_key, true, algorithm: 'RS256')

    expect(headers['kid']).to eq('088d24232ff6faa4cd4cfec126ad0431dff1ea028afdb1c86b3718d70171aed6')
  end

  it 'throws a helpful exception if no key exists to encode payloads' do
    expect { VeteranVerification::Notary.new('a/fake/path') }.to raise_error VeteranVerification::NotaryException
  end
end
