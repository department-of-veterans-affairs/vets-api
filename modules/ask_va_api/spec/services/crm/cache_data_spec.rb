# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::CacheData do
  subject(:cache_data_instance) { described_class.new(service:, cache_client:) }

  let(:service) { Crm::Service.new(icn: nil) }
  let(:cache_client) { AskVAApi::RedisClient.new }
  let(:cache_data) { { Topics: [{ id: 1, name: 'Topic 1' }] } }

  before do
    allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
  end

  describe '#call' do
    context 'when the cache has data' do
      it 'returns data from the cache without calling the service' do
        expect(cache_client).to receive(:fetch).with('categories_topics_subtopics').and_return(cache_data)
        expect(service).not_to receive(:call)
        expect(cache_data_instance.call(endpoint: 'topics', cache_key: 'categories_topics_subtopics')).to eq(cache_data)
      end
    end

    context 'when the cache is empty' do
      it 'fetches data from the service and stores it in the cache' do
        expect(service).to receive(:call).with(endpoint: 'topics', payload: {}).and_return(cache_data)
        expect(cache_client).to receive(:store_data).with(key: 'categories_topics_subtopics',
                                                          data: cache_data,
                                                          ttl: 86_400)
        expect(cache_data_instance.call(endpoint: 'topics',
                                        cache_key: 'categories_topics_subtopics')).to eq(cache_data)
      end
    end

    context 'when an ApiServiceError occurs' do
      let(:body) do
        '{"Data":null,"Message":"Data Validation: Invalid OptionSet Name iris_branchofservic, valid' \
          ' values are iris_inquiryabout, iris_inquirysource, iris_inquirytype, iris_levelofauthentication,' \
          ' iris_suffix, iris_veteranrelationship, iris_branchofservice, iris_country, iris_province,' \
          ' iris_responsetype, iris_dependentrelationship, statuscode, iris_messagetype","ExceptionOccurred":' \
          'true,"ExceptionMessage":"Data Validation: Invalid OptionSet Name iris_branchofservic, valid' \
          ' values are iris_inquiryabout, iris_inquirysource, iris_inquirytype, iris_levelofauthentication,' \
          ' iris_suffix, iris_veteranrelationship, iris_branchofservice, iris_country, iris_province,' \
          ' iris_responsetype, iris_dependentrelationship, statuscode, iris_messagetype","MessageId":' \
          '"6dfa81bd-f04a-4f39-88c5-1422d88ed3ff"}'
      end
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }
      let(:response) do
        cache_data_instance.call(
          endpoint: 'optionset',
          cache_key: 'branchofservic',
          payload: { name: 'iris_branchofservic' }
        )
      end

      before do
        allow_any_instance_of(Crm::Service).to receive(:call)
          .with(endpoint: 'optionset', payload: { name: 'iris_branchofservic' })
          .and_return(failure)
      end

      it 'handles the service error through the ErrorHandler' do
        expect { response }.to raise_error(Crm::CacheDataError)
      end
    end

    context 'when a Redis::BaseError occurs' do
      let(:response) do
        cache_data_instance.call(
          endpoint: 'optionset',
          cache_key: 'branchofservice',
          payload: { name: 'iris_branchofservice' }
        )
      end

      before do
        allow_any_instance_of(AskVAApi::RedisClient).to receive(:fetch)
          .and_raise(Redis::BaseError, 'Redis connection error')
      end

      it 'raises a CacheStoreError' do
        expect { response }.to raise_error(
          Crm::CacheDataError, 'Crm::CacheStoreError: Cache store failure: Redis connection error'
        )
      end
    end
  end
end
