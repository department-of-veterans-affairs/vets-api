# frozen_string_literal: true

require 'rails_helper'

describe Eps::AccessTokenStore do
  subject { described_class }

  let(:access_token) { 'test-access-token' }
  let(:token_type) { 'jwt_bearer' }
  let(:redis_key) { "eps-access-token:#{token_type}" }
  let(:cache_data) { { token_type:, access_token: } }
  let(:token_store_client) { subject.new(token_type:, access_token:) }

  before do
    token_store_client.save
  end

  describe '#save' do
    it 'saves the value in cache' do
      token = Oj.load($redis.get(redis_key))[:access_token]
      expect(token).to eq(access_token)
    end
  end

  describe '#ttl' do
    it 'sets cache data expire to time from config file' do
      expect($redis.ttl(redis_key)).to eq(900)
    end
  end

  describe '#find' do
    it 'gets data from cache' do
      expect(Oj.load($redis.get(redis_key))).to eq(cache_data)
    end
  end
end
