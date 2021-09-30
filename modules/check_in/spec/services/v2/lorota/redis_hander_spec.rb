# frozen_string_literal: true

require 'rails_helper'

describe V2::Lorota::RedisHandler do
  subject { described_class }

  let(:opts) do
    {
      data: {
        uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
        last4: '1234',
        last_name: 'Johnson'
      },
      jwt: nil
    }
  end
  let(:check_in) { CheckIn::V2::Session.build(opts) }
  let(:redis_handler) { subject.build(check_in: check_in) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe 'attributes' do
    it 'responds to check_in' do
      expect(redis_handler.respond_to?(:check_in)).to be(true)
    end

    it 'responds to settings' do
      expect(redis_handler.respond_to?(:settings)).to be(true)
    end

    it 'responds to token' do
      expect(redis_handler.respond_to?(:token)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of RedisHandler' do
      expect(redis_handler).to be_an_instance_of(V2::Lorota::RedisHandler)
    end
  end

  describe '#get' do
    context 'when cache exists' do
      it 'returns the cached value' do
        Rails.cache.write(
          'check_in_lorota_v2_d602d9eb-9a31-484f-9637-13ab0b507e0d_read.full',
          '12345',
          namespace: 'check-in-lorota-v2-cache'
        )

        expect(redis_handler.get).to eq('12345')
      end
    end

    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_handler.get).to eq(nil)
      end
    end
  end

  describe '#save' do
    it 'is true' do
      allow_any_instance_of(V2::Lorota::Token).to receive(:access_token).and_return('12345')
      allow_any_instance_of(subject).to receive(:token).and_return(V2::Lorota::Token.build(check_in: check_in))

      expect(redis_handler.save).to eq(true)
    end
  end
end
