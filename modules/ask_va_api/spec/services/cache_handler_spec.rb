# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CacheHandler do
  let(:cache_handler) { described_class.new }

  describe '#cache_data' do
    let(:handler) { Struct.new(:data, :cache?) }
    let!(:data) { handler.new(data: 'test data', cache?: true) }

    it 'caches and retrieves data' do
      key = 'test_key'

      # Cache data
      cached_data = cache_handler.cache_data(key) do
        data
      end

      expected_data = cache_handler.class.find(key)
      expect(cached_data.data).to eq(expected_data.response.data)

      # Retrieve cached data
      retrieved_data = cache_handler.cache_data(key) do
        data
      end

      expect(retrieved_data.data).to eq(cached_data.data)
    end
  end
end
