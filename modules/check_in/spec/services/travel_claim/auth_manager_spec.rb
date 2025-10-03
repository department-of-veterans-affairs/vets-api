# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::AuthManager do
  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:session) { CheckIn::V2::Session.build(data: { uuid: }) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe '#authorize' do
    it 'raises when ICN is missing and no session provided' do
      service = described_class.new
      expect { service.authorize }.to raise_error(ArgumentError, /ICN not available/)
    end

    it 'raises when ICN is missing in Redis with session provided' do
      allow_any_instance_of(TravelClaim::RedisClient).to receive(:icn).and_return(nil)
      service = described_class.new(check_in_session: session)
      expect { service.authorize }.to raise_error(ArgumentError, /ICN not available/)
    end

    it 'returns cached token when present (provided icn; non-PHI key)' do
      icn = '123V456'
      service = described_class.new
      key = service.send(:secure_cache_key, icn)
      expect(key).not_to include(icn)

      # Cached via redis_client v4_token storage
      service.redis_client.save_v4_token(cache_key: key, token: 'cached-token')

      token = service.authorize(icn:)
      expect(token).to eq('cached-token')
    end

    it 'returns cached token when present (session uuid key)' do
      allow_any_instance_of(TravelClaim::RedisClient).to receive(:icn).and_return('123V456')
      service = described_class.new(check_in_session: session)
      key = service.send(:secure_cache_key, '123V456')
      expect(key).to include(uuid)

      service.redis_client.save_v4_token(cache_key: key, token: 'cached-token')

      token = service.authorize
      expect(token).to eq('cached-token')
    end

    it 'fetches veis and v4 tokens and caches the result (with provided icn)' do
      icn = '123V456'
      token_client = instance_double(TravelClaim::TokenClient)
      allow(TravelClaim::TokenClient).to receive(:new).and_return(token_client)

      veis_resp = Faraday::Response.new(response_body: { access_token: 'veis' }.to_json, status: 200)
      v4_resp = Faraday::Response.new(response_body: { data: { accessToken: 'v4' } }.to_json, status: 200)
      allow(token_client).to receive(:veis_token).and_return(veis_resp)
      allow(token_client).to receive(:system_access_token_v4).with(veis_access_token: 'veis',
                                                                   icn:).and_return(v4_resp)

      service = described_class.new
      # Spy on save_v4_token
      allow(service.redis_client).to receive(:save_v4_token).and_call_original

      token = service.authorize(icn:)
      expect(token).to eq('v4')

      key = service.send(:secure_cache_key, icn)
      cached = service.redis_client.v4_token(cache_key: key)
      expect(cached).to eq('v4')
      expect(service.redis_client).to have_received(:save_v4_token).with(cache_key: key, token: 'v4')
    end

    it 'resolves icn from Redis when not passed' do
      allow_any_instance_of(TravelClaim::RedisClient).to receive(:icn).and_return('123V456')

      token_client = instance_double(TravelClaim::TokenClient)
      allow(TravelClaim::TokenClient).to receive(:new).and_return(token_client)
      veis_resp = Faraday::Response.new(response_body: { access_token: 'veis' }.to_json, status: 200)
      v4_resp = Faraday::Response.new(response_body: { data: { accessToken: 'v4' } }.to_json, status: 200)
      allow(token_client).to receive(:veis_token).and_return(veis_resp)
      allow(token_client).to receive(:system_access_token_v4).with(veis_access_token: 'veis',
                                                                   icn: '123V456').and_return(v4_resp)

      service = described_class.new(check_in_session: session)
      allow(service.redis_client).to receive(:save_v4_token).and_call_original

      token = service.authorize
      expect(token).to eq('v4')

      key = service.send(:secure_cache_key, '123V456')
      expect(service.redis_client.v4_token(cache_key: key)).to eq('v4')
      expect(service.redis_client).to have_received(:save_v4_token).with(cache_key: key, token: 'v4')
    end
  end

  describe '#request_new_tokens' do
    it 'returns and persists both veis and v4 tokens (provided icn)' do
      icn = '123V456'
      token_client = instance_double(TravelClaim::TokenClient)
      allow(TravelClaim::TokenClient).to receive(:new).and_return(token_client)

      veis_resp = Faraday::Response.new(response_body: { access_token: 'veis' }.to_json, status: 200)
      v4_resp = Faraday::Response.new(response_body: { data: { accessToken: 'v4' } }.to_json, status: 200)
      allow(token_client).to receive(:veis_token).and_return(veis_resp)
      allow(token_client).to receive(:system_access_token_v4).with(veis_access_token: 'veis',
                                                                   icn:).and_return(v4_resp)

      service = described_class.new
      # Spy on redis_client token writes
      allow(service.redis_client).to receive(:save_token).and_call_original
      allow(service.redis_client).to receive(:save_v4_token).and_call_original

      result = service.request_new_tokens(icn:)
      expect(result).to eq({ veis_token: 'veis', btsss_token: 'v4' })

      expect(service.redis_client).to have_received(:save_token).with(token: 'veis')

      key = service.send(:secure_cache_key, icn)
      expect(service.redis_client.v4_token(cache_key: key)).to eq('v4')
      expect(service.redis_client).to have_received(:save_v4_token).with(cache_key: key, token: 'v4')
    end

    it 'resolves icn via session and persists tokens' do
      allow_any_instance_of(TravelClaim::RedisClient).to receive(:icn).and_return('ICN999')

      token_client = instance_double(TravelClaim::TokenClient)
      allow(TravelClaim::TokenClient).to receive(:new).and_return(token_client)

      veis_resp = Faraday::Response.new(response_body: { access_token: 'veis' }.to_json, status: 200)
      v4_resp = Faraday::Response.new(response_body: { data: { accessToken: 'v4' } }.to_json, status: 200)
      allow(token_client).to receive(:veis_token).and_return(veis_resp)
      allow(token_client).to receive(:system_access_token_v4).with(veis_access_token: 'veis',
                                                                   icn: 'ICN999').and_return(v4_resp)

      service = described_class.new(check_in_session: session)
      allow(service.redis_client).to receive(:save_token).and_call_original
      allow(service.redis_client).to receive(:save_v4_token).and_call_original

      result = service.request_new_tokens
      expect(result).to eq({ veis_token: 'veis', btsss_token: 'v4' })
      expect(service.redis_client).to have_received(:save_token).with(token: 'veis')

      key = service.send(:secure_cache_key, 'ICN999')
      expect(service.redis_client.v4_token(cache_key: key)).to eq('v4')
      expect(service.redis_client).to have_received(:save_v4_token).with(cache_key: key, token: 'v4')
    end

    it 'raises when ICN cannot be resolved' do
      allow_any_instance_of(TravelClaim::RedisClient).to receive(:icn).and_return(nil)
      service = described_class.new(check_in_session: session)
      expect { service.request_new_tokens }.to raise_error(ArgumentError, /ICN not available/)
    end
  end

  describe '#secure_cache_key' do
    it 'uses settings.cache_key_secret when present' do
      service = described_class.new
      sd = OpenStruct.new(cache_key_secret: 'sekret')
      allow(service).to receive(:settings).and_return(sd)
      expect(OpenSSL::HMAC).to receive(:hexdigest).with('SHA256', 'sekret', 'ICN').and_return('d')
      key = service.send(:secure_cache_key, 'ICN')
      expect(key).to include('icn_hmac:d')
    end

    it 'falls back to credentials secret_key_base when settings secret is absent' do
      service = described_class.new
      sd = OpenStruct.new(cache_key_secret: nil)
      fake_creds = double('creds', secret_key_base: 'cred-secret')
      fake_app = double('app', credentials: fake_creds)
      allow(Rails).to receive(:application).and_return(fake_app)
      allow(service).to receive(:settings).and_return(sd)
      expect(OpenSSL::HMAC).to receive(:hexdigest).with('SHA256', 'cred-secret', 'ICN').and_return('d2')
      key = service.send(:secure_cache_key, 'ICN')
      expect(key).to include('icn_hmac:d2')
    end

    it 'uses hardcoded fallback when neither settings nor credentials provide a secret' do
      service = described_class.new
      sd = OpenStruct.new(cache_key_secret: nil)
      fake_creds = double('creds', secret_key_base: nil)
      fake_app = double('app', credentials: fake_creds)
      allow(Rails).to receive(:application).and_return(fake_app)
      allow(service).to receive(:settings).and_return(sd)
      expect(OpenSSL::HMAC).to receive(:hexdigest).with('SHA256', 'checkin-travel-pay', 'ICN').and_return('d3')
      key = service.send(:secure_cache_key, 'ICN')
      expect(key).to include('icn_hmac:d3')
    end
  end
end
