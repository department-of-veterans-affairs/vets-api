# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::RedisClient do
  let(:redis_client) { AskVAApi::RedisClient.new }
  let(:token) { 'some-access-token' }

  describe '#fetch' do
    it 'fetch data from the cache' do
      allow(Rails.cache).to receive(:read).with('token', namespace: 'crm-api-cache').and_return(token)

      expect(redis_client.fetch('token')).to eq(token)
    end
  end

  describe '#store_data' do
    it 'writes the data to the cache with an expiry time' do
      expect(Rails.cache).to receive(:write).with(
        'token',
        token,
        namespace: 'crm-api-cache',
        expires_in: 3540
      )

      redis_client.store_data(key: 'token', data: token, ttl: 3540)
    end
  end
end
