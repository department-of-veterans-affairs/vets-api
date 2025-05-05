# frozen_string_literal: true

require 'rails_helper'
require 'vets/model'
require 'vets/collections/cacheable'

RSpec.describe Vets::Collections::Cacheable do
  let(:dummy_model) do
    Class.new do
      include Comparable

      attr_reader :id

      def initialize(id:)
        @id = id
      end

      def <=>(other)
        id <=> other.id
      end
    end
  end

  let(:dummy_collection_class) do
    Class.new do
      include Vets::Collections::Cacheable

      attr_reader :records, :metadata, :cache_key

      def initialize(records, _klass, metadata: {}, errors: {}, cache_key: nil)
        @records = records
        @metadata = metadata
        @cache_key = cache_key
      end

      def serialize
        Oj.dump({ data: @records.map { |r| { id: r.id } }, metadata: @metadata })
      end
    end
  end

  let(:record) { dummy_model.new(id: 1) }
  let(:cache_key) { 'test_key' }
  let(:redis_namespace) do
    Redis::Namespace.new("common_collection_#{SecureRandom.hex(4)}", redis: Redis.new)
  end
  let(:instance_with_cache) { dummy_collection_class.new([record], dummy_model, cache_key: cache_key) }
  let(:instance_without_cache) { dummy_collection_class.new([record], dummy_model) }

  before do
    allow(Redis::Namespace).to receive(:new).and_return(redis_namespace)
  end

  after do
    redis_namespace.redis.flushdb
  end

  describe '.redis_namespace' do
    it 'has the correct namespace' do
      expect(dummy_collection_class.redis_namespace.namespace).to include("common_collection_")
    end
  end

  describe '.fetch' do
    it 'builds and caches when key is missing' do
      result = dummy_collection_class.fetch(dummy_model, cache_key: cache_key) do
        { data: [record], metadata: {} }
      end

      expect(result.records.first.id).to eq(1)
      expect(result.metadata).to eq({})
    end

    it 'raises ArgumentError without a block' do
      expect {
        dummy_collection_class.fetch(dummy_model, cache_key: cache_key)
      }.to raise_error(ArgumentError, 'No block given')
    end
  end

  describe '.cache' do
    it 'writes data to redis and sets TTL' do
      dummy_collection_class.cache('{"foo":"bar"}', cache_key, 60)
      expect(redis_namespace.get(cache_key)).to eq('{"foo":"bar"}')
      expect(redis_namespace.ttl(cache_key)).to be <= 60
    end
  end

  describe '.bust' do
    it 'deletes the key from redis' do
      redis_namespace.set(cache_key, '{"foo":"bar"}')
      expect(redis_namespace.get(cache_key)).to eq('{"foo":"bar"}')

      dummy_collection_class.bust(cache_key)
      expect(redis_namespace.get(cache_key)).to be_nil
    end

    it 'handles array of keys' do
      keys = [cache_key, "#{cache_key}_2"]
      keys.each { |k| redis_namespace.set(k, '{"foo":"bar"}') }

      dummy_collection_class.bust(keys)
      keys.each { |k| expect(redis_namespace.get(k)).to be_nil }
    end
  end

  describe '#redis_namespace' do
    it 'returns the same Redis::Namespace as the class method' do
      expect(instance_with_cache.redis_namespace).to eq(dummy_collection_class.redis_namespace)
    end
  end

  describe '#ttl' do
    it 'returns ttl if cached' do
      json_data = '{"foo":"bar"}'
      dummy_collection_class.cache(json_data, cache_key, 1234)

      expect(instance_with_cache.ttl).to eq(1234)
    end

    it 'returns nil if not cached' do
      expect(instance_without_cache.ttl).to be_nil
    end
  end

  describe '#bust' do
    context 'when cached' do
      before do
        dummy_collection_class.cache('{"foo":"bar"}', cache_key, 60)
      end

      it 'removes the cache' do
        expect(redis_namespace.get(cache_key)).to eq('{"foo":"bar"}')
        instance_with_cache.bust
        expect(redis_namespace.get(cache_key)).to be_nil
      end
    end

    context 'when not cached' do
      it 'does not call the Redis cache' do
        expect(redis_namespace).not_to receive(:get)
        instance_without_cache.bust
      end
    end
  end

  describe '#cached?' do
    it 'returns true when cache_key is present' do
      expect(instance_with_cache.cached?).to eq(true)
    end

    it 'returns false when cache_key is nil' do
      expect(instance_without_cache.cached?).to eq(false)
    end
  end
end
