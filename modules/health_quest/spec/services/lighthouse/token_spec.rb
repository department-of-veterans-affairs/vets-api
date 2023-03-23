# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Lighthouse::Token do
  subject { described_class }

  let(:user) { double('User', account_uuid: 'abc123', icn: '1008596379V859838') }
  let(:token) { subject.build(user:, api: 'pgd_api') }

  describe 'constants' do
    it 'has an ACCESS_TOKEN' do
      expect(subject::ACCESS_TOKEN).to eq('access_token')
    end

    it 'has an EXPIRATION' do
      expect(subject::EXPIRATION).to eq('exp')
    end

    it 'has a SCOPES_DELIMITER' do
      expect(subject::SCOPES_DELIMITER).to eq(' ')
    end
  end

  describe 'attributes' do
    it 'responds to api' do
      expect(token.respond_to?(:api)).to be(true)
    end

    it 'responds to user' do
      expect(token.respond_to?(:user)).to be(true)
    end

    it 'responds to request' do
      expect(token.respond_to?(:request)).to be(true)
    end

    it 'responds to claims_token' do
      expect(token.respond_to?(:claims_token)).to be(true)
    end

    it 'responds to access_token' do
      expect(token.respond_to?(:access_token)).to be(true)
    end

    it 'responds to decoded_token' do
      expect(token.respond_to?(:decoded_token)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of Token' do
      expect(token).to be_an_instance_of(HealthQuest::Lighthouse::Token)
    end
  end

  describe '#fetch' do
    let(:sample_access_token) do
      'eyJraWQiOiJRMFZKbEt0TU9rYUxXTEtxdXhsTllHQzFRLWMtblQzYjRWVlJLaXB4TThzIiwiYWxnIj' \
        'oiUlMyNTYifQ.eyJ2ZXIiOjEsImp0aSI6IkFULjVTcDV4QnNZQzdXQU1MU2ZOR3JETlFmS0JQaHpWaW' \
        'VwQ1NYbHhPODBKV1kiLCJpc3MiOiJodHRwczovL2RlcHR2YS1ldmFsLm9rdGEuY29tL29hdXRoMi9hdX' \
        'M4eDI3bnY0ZzRCUzAxdjJwNyIsImF1ZCI6Imh0dHBzOi8vc2FuZGJveC1hcGkudmEuZ292L3NlcnZpY2V' \
        'zL3BnZCIsImlhdCI6MTYxMDExODk3NywiZXhwIjoxNjEwMTE5Mjc3LCJjaWQiOiIwb2E5Z3Z3ZjVtdnhj' \
        'WDN6SDJwNyIsInNjcCI6WyJwYXRpZW50L1BhdGllbnQucmVhZCIsImxhdW5jaC9wYXRpZW50Il0sInN1Yi' \
        'I6IjBvYTlndndmNW12eGNYM3pIMnA3In0.Z_1xLenmVFZwqkboOGB8xdRvoiWmn1kFaPDBklOz2vRncuKX' \
        'HFuiHqsULMM9Jr4IimSyhhSX26A0AQZj5F1LcS4I1N_CeJEiCzCr4ZuihUd6HFeP5g3wbtLekrPWL697vVX' \
        'itUytDpcaWlUTTtW1pzfNKFVyb-m5Z3votzqLPp9tV_DdhnkbwnEuAFKp-lIkOfBfZtB7_Orv55xunvNeY6R' \
        '-j-DjMgjNn7Xmn3-h_PXi9doVwp5KOdoTD3fX9t4EZy0zRFgN3zz5DahVmBEq65Sy9KLzmu_CL9wF2CEqgQz' \
        '4rOGK0j6RcoezpJwuABi61a3WOGMJx6kT3eytuzA-UA'
    end
    let(:faraday_response) { double('Faraday::Response', body: { 'access_token' => sample_access_token }.to_json) }

    it 'returns an instance of Token' do
      allow_any_instance_of(HealthQuest::Lighthouse::Request).to receive(:post)
        .with(anything, anything).and_return(faraday_response)

      expect(token.fetch).to be_an_instance_of(subject)
    end
  end

  describe '#created_at' do
    it 'is an Integer' do
      expect(token.created_at).to be_a(Integer)
    end
  end

  describe '#ttl_duration' do
    it 'is an Integer' do
      token.decoded_token = { 'exp' => 5.minutes.from_now.utc.to_i }

      expect(token.ttl_duration).to be_a(Integer)
    end
  end

  describe '#api_paths' do
    context 'when pgd_api' do
      it 'returns the pgd token path' do
        pgd_token_path = '/oauth2/pgd/v1/token'

        expect(token.api_paths['pgd_api']).to eq(pgd_token_path)
      end
    end

    context 'when health_api' do
      it 'returns the health token path' do
        health_token_path = '/oauth2/health/system/v1/token'

        expect(token.api_paths['health_api']).to eq(health_token_path)
      end
    end
  end

  describe '#scopes' do
    context 'when pgd_api' do
      it 'returns the pgd api scopes' do
        expect(token.scopes['pgd_api']).to eq(Settings.hqva_mobile.lighthouse.pgd_api_scopes)
      end
    end

    context 'when health_api' do
      it 'returns the health api scopes' do
        expect(token.scopes['health_api']).to eq(Settings.hqva_mobile.lighthouse.health_api_scopes)
      end
    end
  end

  describe '#base64_encoded_launch' do
    it 'base64 encodes the launch object' do
      expect(token.base64_encoded_launch).to eq('eyI6cGF0aWVudCI6IjEwMDg1OTYzNzlWODU5ODM4In0=')
    end
  end

  describe '#post_params' do
    context 'when pgd_api' do
      it 'sets the pgd scopes' do
        scopes = Settings.hqva_mobile.lighthouse.pgd_api_scopes.join(' ')
        matched_scope = URI.encode_www_form(scope: scopes)

        expect(token.post_params).to include(matched_scope)
      end
    end

    context 'when health_api' do
      let(:token) { subject.build(user:, api: 'health_api') }

      it 'sets the health scopes' do
        scopes = Settings.hqva_mobile.lighthouse.health_api_scopes.join(' ')
        matched_scope = URI.encode_www_form(scope: scopes)

        expect(token.post_params).to include(matched_scope)
      end
    end
  end
end
