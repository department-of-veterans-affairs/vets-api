# frozen_string_literal: true

require 'rails_helper'
require 'digital_forms_api/jwt_generator'

RSpec.describe DigitalFormsApi::JwtGenerator do
  let(:private_key) { 'test_secret_key' }
  let(:generator) { described_class.new(private_key:) }
  let(:payload) { { user_id: 123, data: 'test' } }

  describe 'constants' do
    it 'has correct VALIDITY_LENGTH' do
      expect(described_class::VALIDITY_LENGTH).to eq(30.minutes)
    end

    it 'has correct ALGORITHM' do
      expect(described_class::ALGORITHM).to eq('HS256')
    end

    it 'has correct ISSUER' do
      expect(described_class::ISSUER).to eq('vets-api')
    end
  end

  describe '#initialize' do
    it 'sets the private key' do
      expect(generator.instance_variable_get(:@private_key)).to eq(private_key)
    end
  end

  describe '#generate' do
    it 'generates a JWT token' do
      token = generator.generate(payload)

      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3) # JWT has 3 parts
    end

    it 'encodes the payload correctly' do
      token = generator.generate(payload)
      decoded = JWT.decode(token, private_key, true, { algorithm: 'HS256' }).first

      expect(decoded['user_id']).to eq(123)
      expect(decoded['data']).to eq('test')
    end

    it 'uses the correct algorithm' do
      token = generator.generate(payload)
      header = JSON.parse(Base64.decode64(token.split('.').first))

      expect(header['alg']).to eq('HS256')
    end
  end
end
