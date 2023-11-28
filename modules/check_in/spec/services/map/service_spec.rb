# frozen_string_literal: true

require 'rails_helper'

describe Map::Service do
  subject { described_class }

  let(:patient_identifier) { '123' }
  let(:opts) do
    {
      patient_identifier:
    }
  end
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.build(opts)).to be_an_instance_of(described_class)
    end
  end

  describe '#initialize' do
    it 'has a redis client' do
      expect(subject.build(opts).redis_client).to be_a(Map::RedisClient)
    end
  end
end
