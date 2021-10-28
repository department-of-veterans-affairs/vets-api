# frozen_string_literal: true

require 'rails_helper'

describe V2::Lorota::Session do
  subject { described_class.build(check_in: check_in) }

  let(:opts) do
    {
      data: {
        uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
        last4: '1234',
        last_name: 'Johnson'
      }
    }
  end
  let(:check_in) { CheckIn::V2::Session.build(opts) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe 'attributes' do
    it 'responds to redis_handler' do
      expect(subject.respond_to?(:redis_handler)).to be(true)
    end

    it 'responds to token' do
      expect(subject.respond_to?(:token)).to be(true)
    end

    it 'responds to check_in' do
      expect(subject.respond_to?(:check_in)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of Session' do
      expect(subject).to be_an_instance_of(V2::Lorota::Session)
    end
  end

  describe '#from_redis' do
    context 'when cache exists' do
      it 'returns the token' do
        Rails.cache.write(
          'check_in_lorota_v2_d602d9eb-9a31-484f-9637-13ab0b507e0d_read.full',
          '12345',
          namespace: 'check-in-lorota-v2-cache'
        )

        expect(subject.from_redis).to eq('12345')
      end
    end

    context 'when cache does not exist' do
      it 'returns nil' do
        allow_any_instance_of(V2::Lorota::RedisHandler).to receive(:get).and_return(nil)

        expect(subject.from_redis).to eq(nil)
      end
    end
  end

  describe '#from_lorota' do
    let(:token) { V2::Lorota::Token.build(check_in: check_in) }

    it 'returns the token' do
      allow(token).to receive(:access_token).and_return('12345')
      allow_any_instance_of(V2::Lorota::Token).to receive(:fetch).and_return(token)

      expect(subject.from_lorota).to eq('12345')
    end
  end
end
