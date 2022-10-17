# frozen_string_literal: true

require 'rails_helper'

describe TravelClaim::Service do
  subject { described_class }

  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in) { CheckIn::V2::Session.build(data: { uuid: uuid }) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.build(check_in: check_in)).to be_an_instance_of(described_class)
    end
  end

  describe '#initialize' do
    it 'has a check_in session' do
      expect(subject.build(check_in: check_in).check_in).to be_a(CheckIn::V2::Session)
    end

    it 'has a redis client' do
      expect(subject.build(check_in: check_in).redis_client).to be_a(TravelClaim::RedisClient)
    end
  end

  describe '#token' do
    let(:access_token) { 'test-token-123' }

    context 'when it exists in redis' do
      before do
        allow_any_instance_of(TravelClaim::RedisClient).to receive(:get).and_return(access_token)
      end

      it 'returns token from redis' do
        expect(subject.build.token).to eq(access_token)
      end
    end

    context 'when it does not exist in redis' do
      before do
        expect_any_instance_of(TravelClaim::Client).to receive(:token)
          .and_return(Faraday::Response.new(body: { access_token: access_token }.to_json, status: 200))
      end

      it 'returns token by calling client' do
        expect(subject.build.token).to eq(access_token)
      end
    end
  end
end
