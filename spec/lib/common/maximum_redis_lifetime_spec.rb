# frozen_string_literal: true

require 'rails_helper'
require 'common/models/concerns/maximum_redis_lifetime'

RSpec.describe Common::MaximumRedisLifetime do
  context 'when superclass is not RedisStore' do
    let(:clazz) do
      class SomeClass
        include Common::MaximumRedisLifetime
      end
    end
    it 'raises exception' do
      expect do
        clazz
      end.to raise_exception(ArgumentError)
    end
  end
end
