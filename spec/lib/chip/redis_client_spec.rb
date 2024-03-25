# frozen_string_literal: true

require 'rails_helper'
require 'chip/redis_client'

describe Chip::RedisClient do
  let(:tenant_id) { '12345678-abcd-aaaa-bbbb-283f55efb0ea' }
  let(:redis_client) { described_class.build(tenant_id) }

  describe '.build' do
    it 'returns an instance of RedisClient' do
      expect(redis_client).to be_an_instance_of(Chip::RedisClient)
    end
  end

  describe '.get' do
    let(:token) { 'test_token' }

    before do
      redis_client.save(token:)
    end

    it 'returns saved entry' do
      expect(redis_client.get).to eq(token)
    end
  end

  describe '.save' do
    let(:token) { 'test_token' }

    it 'saves entry' do
      expect_any_instance_of(Redis).to receive(:set).once.with(
        "chip:#{tenant_id}", 'test_token', { ex: REDIS_CONFIG[:chip][:each_ttl] }
      )
      redis_client.save(token:)
    end
  end

  describe 'ttl' do
    it 'returns correct value of ttl' do
      expect(redis_client.ttl).to eq(REDIS_CONFIG[:chip][:each_ttl])
    end
  end

  describe 'namespace' do
    it 'returns correct value of namespace' do
      expect(redis_client.namespace).to eq(REDIS_CONFIG[:chip][:namespace])
    end
  end
end
