# frozen_string_literal: true

require 'rails_helper'

describe Eps::BaseService do
  let(:user) { double('User', account_uuid: '1234') }
  let(:service) { described_class.new(user) }
  let(:mock_token_response) { double('Response', body: { 'access_token' => 'mock_token' }) }

  describe '#headers' do
    before do
      allow(RequestStore.store).to receive(:[]).with('request_id').and_return('request-id')
      allow(service).to receive(:token).and_return('test_token')
    end

    it 'returns the correct headers' do
      expected_headers = {
        'Authorization' => 'Bearer test_token',
        'Content-Type' => 'application/json',
        'X-Request-ID' => 'request-id'
      }
      expect(service.headers).to eq(expected_headers)
    end
  end

  describe '#config' do
    it 'returns the Eps::Configuration instance' do
      expect(service.config).to be_instance_of(Eps::Configuration)
    end
  end

  describe '#token' do
    context 'when cache is empty' do
      before do
        allow(Rails.cache).to receive(:fetch)
          .with(described_class::REDIS_TOKEN_KEY, expires_in: described_class::REDIS_TOKEN_TTL)
          .and_yield
        allow(service).to receive(:get_token).and_return(mock_token_response)
      end

      it 'fetches and caches new token' do
        expect(service.token).to eq('mock_token')
      end
    end

    context 'when cache exists' do
      before do
        allow(Rails.cache).to receive(:fetch)
          .with(described_class::REDIS_TOKEN_KEY, expires_in: described_class::REDIS_TOKEN_TTL)
          .and_return('cached_token')
      end

      it 'returns cached token' do
        expect(service.send(:token)).to eq('cached_token')
      end
    end
  end
end
