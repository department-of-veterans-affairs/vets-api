# frozen_string_literal: true

require 'rails_helper'

describe Eps::BaseService do
  user_icn = '123456789V123456'

  let(:user) { double('User', account_uuid: '1234', icn: user_icn) }
  let(:service) { described_class.new(user) }
  let(:config) { instance_double(Eps::Configuration) }
  let(:request_id) { '123456-abcdef' }
  let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(service).to receive(:config).and_return(config)
    RequestStore.store['request_id'] = request_id
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe '#config' do
    it 'returns the Eps::Configuration instance' do
      allow(service).to receive(:config).and_call_original
      expect(service.config).to be_instance_of(Eps::Configuration)
    end
  end

  describe '#patient_id' do
    it 'returns the user ICN' do
      expect(service.send(:patient_id)).to eq(user_icn)
    end

    it 'memoizes the ICN' do
      expect(user).to receive(:icn).once.and_return(user_icn)
      2.times { service.send(:patient_id) }
    end
  end

  describe '#request_headers_with_correlation_id' do
    context 'when mocks are enabled' do
      before do
        allow(config).to receive(:mock_enabled?).and_return(true)
      end

      it 'returns empty hash' do
        expect(service.send(:request_headers_with_correlation_id)).to eq({})
      end
    end

    context 'when mocks are disabled' do
      before do
        allow(config).to receive(:mock_enabled?).and_return(false)
        # Mock the token authentication method to avoid actual API calls
        allow(service).to receive(:headers_with_correlation_id).and_return({
                                                                             'Authorization' => 'Bearer test-token',
                                                                             'Content-Type' => 'application/json',
                                                                             'X-Request-ID' => 'test-correlation-id',
                                                                             'X-Parent-Request-ID' => request_id
                                                                           })
      end

      it 'delegates to headers_with_correlation_id method' do
        expect(service).to receive(:headers_with_correlation_id)
        service.send(:request_headers_with_correlation_id)
      end

      it 'returns the headers from token authentication' do
        headers = service.send(:request_headers_with_correlation_id)
        expect(headers).to eq({
                                'Authorization' => 'Bearer test-token',
                                'Content-Type' => 'application/json',
                                'X-Request-ID' => 'test-correlation-id',
                                'X-Parent-Request-ID' => request_id
                              })
      end
    end
  end
end
