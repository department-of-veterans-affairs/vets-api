# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Lighthouse::ClaimsToken do
  subject { described_class }

  describe 'constants' do
    it 'has an EXPIRATION_DURATION of 15' do
      expect(subject::EXPIRATION_DURATION).to eq(15)
    end

    it 'has a SIGNING_ALGORITHM of RS512' do
      expect(subject::SIGNING_ALGORITHM).to eq('RS512')
    end

    it 'has a TOKEN_PATH of /v1/token' do
      expect(subject::TOKEN_PATH).to eq('/v1/token')
    end
  end

  describe '.build' do
    it 'returns an instance of ClaimsToken' do
      expect(subject.build).to be_an_instance_of(HealthQuest::Lighthouse::ClaimsToken)
    end
  end

  describe '#sign_assertion' do
    it 'is a String' do
      expect(subject.build.sign_assertion).to be_a(String)
    end

    it 'decoded jwt token has a set of keys' do
      signed_claims = subject.build.sign_assertion

      expect(JWT.decode(signed_claims, nil, false).first.keys.sort).to eq(%w[aud exp iat iss jti sub])
    end
  end
end
