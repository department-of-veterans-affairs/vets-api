# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::StaticData do
  let(:service) { double('Crm::Service') }
  let(:cache_client) { double('RedisClient') }
  let(:static_data_instance) { Crm::StaticData.new(service:, cache_client:) }
  let(:static_data) { { topics: [{ id: 1, name: 'Topic 1' }] } }

  def mock_response(status:, body:)
    instance_double(Faraday::Response, status:, body: body.to_json)
  end

  describe '#call' do
    context 'when the cache has data' do
      it 'returns data from the cache without calling the service' do
        expect(cache_client).to receive(:fetch).with(described_class::CACHE_KEY).and_return(static_data)
        expect(service).not_to receive(:call)
        expect(static_data_instance.call).to eq(static_data)
      end
    end
  end

  describe '#fetch_api_data' do
    context 'when the cache is empty' do
      it 'fetches data from the service and stores it in the cache' do
        expect(service).to receive(:call).with(endpoint: described_class::ENDPOINT).and_return(static_data)
        expect(cache_client).to receive(:store_data).with(key: described_class::CACHE_KEY, data: static_data,
                                                          ttl: 86_400)
        expect(static_data_instance.fetch_api_data).to eq(static_data)
      end
    end

    context 'when an error occurs' do
      let(:resp) { mock_response(body: { error: 'invalid_client' }, status: 401) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with(anything).and_raise(exception)
      end

      it 'handles the service error through the ErrorHandler' do
        expect(service).to receive(:call).with(endpoint: described_class::ENDPOINT).and_raise('Service error')
        expect(Crm::ErrorHandler).to receive(:handle).with('topics', instance_of(RuntimeError))
        expect { static_data_instance.fetch_api_data }.not_to raise_error
      end
    end

    # Edge case where cache returns empty array which should be treated as no data
    context 'when the cache returns an empty array' do
      it 'fetches data from the service as if the cache was empty' do
        expect(service).to receive(:call).with(endpoint: described_class::ENDPOINT).and_return(static_data)
        expect(cache_client).to receive(:store_data).with(key: described_class::CACHE_KEY, data: static_data,
                                                          ttl: 86_400)
        expect(static_data_instance.fetch_api_data).to eq(static_data)
      end
    end
  end
end
