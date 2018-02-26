# frozen_string_literal: true

require 'rails_helper'
require 'common/models/concerns/maximum_redis_lifetime'

RSpec.describe Common::MaximumRedisLifetime do
  context 'when superclass is not RedisStore' do
    let(:clazz) do
      class Class1
        include Common::MaximumRedisLifetime
      end
    end
    it 'raises exception' do
      expect do
        clazz
      end.to raise_exception(ArgumentError, /RedisStore/)
    end
  end

  context 'when superclass does not contain a "created_at" attribute' do
    let(:clazz) do
      class Class2 < Common::RedisStore
        include Common::MaximumRedisLifetime
        redis_store 'a_store'
        redis_ttl 3600
        redis_key :uuid
      end
      Class2.new
    end
    it 'raises exception' do
      expect do
        clazz
      end.to raise_exception(ArgumentError, /created_at/)
    end
  end
end
