# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::CacheData do
  let(:service) { double('Crm::Service') }
  let(:cache_client) { double('AskVAApi::RedisClient') }
  let(:cache_data_instance) { Crm::CacheData.new(service:, cache_client:) }
  let(:cache_data) { { topics: [{ id: 1, name: 'Topic 1' }] } }

  def mock_response(status:, body:)
    instance_double(Faraday::Response, status:, body: body.to_json)
  end

  describe '#call' do
    context 'when the cache has data' do
      it 'returns data from the cache without calling the service' do
        expect(cache_client).to receive(:fetch).with('categories_topics_subtopics').and_return(cache_data)
        expect(service).not_to receive(:call)
        expect(cache_data_instance.call(endpoint: 'topics', cache_key: 'categories_topics_subtopics')).to eq(cache_data)
      end
    end
  end

  describe '#fetch_api_data' do
    context 'when the cache is empty' do
      it 'fetches data from the service and stores it in the cache' do
        expect(service).to receive(:call).with(endpoint: 'topics', payload: {}).and_return(cache_data)
        expect(cache_client).to receive(:store_data).with(key: 'categories_topics_subtopics', data: cache_data,
                                                          ttl: 86_400)
        expect(cache_data_instance.fetch_api_data(endpoint: 'topics',
                                                  cache_key: 'categories_topics_subtopics')).to eq(cache_data)
      end
    end

    context 'when an error occurs' do
      let(:resp) { mock_response(body: { error: 'invalid_client' }, status: 401) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with(anything).and_raise(exception)
      end

      it 'handles the service error through the ErrorHandler' do
        expect(service).to receive(:call).with(endpoint: 'topics', payload: {}).and_raise('Service error')
        expect(Crm::ErrorHandler).to receive(:handle).with('topics', instance_of(RuntimeError))
        expect do
          cache_data_instance.fetch_api_data(endpoint: 'topics', cache_key: 'categories_topics_subtopics')
        end.not_to raise_error
      end
    end

    # Edge case where cache returns empty array which should be treated as no data
    context 'when the cache returns an empty array' do
      it 'fetches data from the service as if the cache was empty' do
        expect(service).to receive(:call).with(endpoint: 'topics', payload: {}).and_return(cache_data)
        expect(cache_client).to receive(:store_data).with(key: 'categories_topics_subtopics', data: cache_data,
                                                          ttl: 86_400)
        expect(cache_data_instance.fetch_api_data(endpoint: 'topics',
                                                  cache_key: 'categories_topics_subtopics')).to eq(cache_data)
      end
    end
  end
end
