# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::Eps::RedisClient do
  subject { described_class }

  let(:redis_client) { subject.new }

  describe '#save' do
    let(:token) { 'test-access-token' }

    it 'saves the value in cache' do
      expect(redis_client.store(access_token: token)).to eq(true)
      expect(redis_client.cached?(key: 'jwt-bearer')).to eq(true)
    end
  end
end
