# frozen_string_literal: true

require 'rails_helper'

describe Eps::JwtWrapper do
  subject { described_class.new }

  let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:settings) do
    OpenStruct.new({
                     key_path: '/path/to/key.pem',
                     client_id: 'test_client',
                     kid: 'test_kid',
                     audience_claim_url: 'https://test.example.com'
                   })
  end

  before do
    allow(Settings.vaos).to receive(:eps).and_return(settings)
    allow(File).to receive(:read).with('/path/to/key.pem').and_return(rsa_key)
  end

  describe 'constants' do
    it 'has a SIGNING_ALGORITHM' do
      expect(described_class::SIGNING_ALGORITHM).to eq('RS512')
    end
  end

  describe '#initialize' do
    it 'sets default expiration to 5 minutes' do
      expect(subject.expiration).to eq(5)
    end

    it 'initializes settings' do
      expect(subject.settings).to eq(settings)
    end
  end

  describe '#sign_assertion' do
    let(:jwt_token) { subject.sign_assertion }
    let(:decoded_token) do
      JWT.decode(
        jwt_token,
        rsa_key.public_key,
        true,
        algorithm: described_class::SIGNING_ALGORITHM
      )
    end

    it 'returns a valid JWT token' do
      expect { decoded_token }.not_to raise_error
    end

    it 'includes the correct headers' do
      headers = decoded_token.last
      expect(headers['kid']).to eq('test_kid')
      expect(headers['typ']).to eq('JWT')
      expect(headers['alg']).to eq('RS512')
    end

    it 'includes the correct claims' do
      claims = decoded_token.first
      expect(claims['iss']).to eq('test_client')
      expect(claims['sub']).to eq('test_client')
      expect(claims['aud']).to eq('https://test.example.com')
      expect(claims['iat']).to be_within(5).of(Time.zone.now.to_i)
      expect(claims['exp']).to be_within(5).of(5.minutes.from_now.to_i)
    end
  end

  describe '#rsa_key' do
    it 'reads the key from the specified path' do
      expect(File).to receive(:read).with('/path/to/key.pem').once.and_return(rsa_key)
      2.times { subject.rsa_key } # Call twice to test memoization
    end

    it 'returns an RSA key instance' do
      expect(subject.rsa_key).to be_a(OpenSSL::PKey::RSA)
    end

    it 'memoizes the RSA key' do
      first_call = subject.rsa_key
      second_call = subject.rsa_key
      expect(first_call).to eq(second_call)
      expect(File).to have_received(:read).once
    end
  end
end
