# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RedisClient do
  let(:redis_client) { RedisClient.new }
  let(:token) { 'some-access-token' }

  describe '#token' do
    it 'reads the token from the cache' do
      allow(Rails.cache).to receive(:read).with('token', namespace: 'crm-api-cache').and_return(token)

      expect(redis_client.token).to eq(token)
    end
  end

  describe '#cache_data' do
    it 'writes the token to the cache with an expiry time' do
      expect(Rails.cache).to receive(:write).with(
        'token',
        token,
        namespace: 'crm-api-cache',
        expires_in: 3540
      )

      redis_client.cache_data(data: token, name: 'token')
    end
  end
end
