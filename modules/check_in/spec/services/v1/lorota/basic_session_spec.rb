# frozen_string_literal: true

require 'rails_helper'

describe V1::Lorota::BasicSession do
  subject { described_class.build(check_in: check_in) }

  let(:check_in) { CheckIn::PatientCheckIn.build(uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d') }
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
      expect(subject).to be_an_instance_of(V1::Lorota::BasicSession)
    end
  end

  describe '#from_redis' do
    context 'when cache exists' do
      it 'returns the token' do
        Rails.cache.write(
          'check_in_lorota_v1_d602d9eb-9a31-484f-9637-13ab0b507e0d_read.basic',
          '12345',
          namespace: 'check-in-lorota-v1-cache'
        )

        expect(subject.from_redis).to eq('12345')
      end
    end

    context 'when cache does not exist' do
      it 'returns nil' do
        allow_any_instance_of(V1::Lorota::BasicRedisHandler).to receive(:get).and_return(nil)

        expect(subject.from_redis).to eq(nil)
      end
    end
  end

  describe '#from_lorota' do
    let(:token) { V1::Lorota::BasicToken.build(check_in: check_in) }

    it 'returns the token' do
      allow(token).to receive(:access_token).and_return('12345')
      allow_any_instance_of(V1::Lorota::BasicToken).to receive(:fetch).and_return(token)

      expect(subject.from_lorota).to eq('12345')
    end
  end
end
