# frozen_string_literal: true

require 'rails_helper'

describe Eps::BaseService do
  let(:user) { double('User', account_uuid: '1234') }
  let(:service) { described_class.new(user) }
  let(:mock_token_response) { double('Response', body: { 'access_token' => 'mock_token' }) }
  let(:blank_token_response) { double('Response', body: { 'access_token' => '' }) }

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

      context 'when get_token returns a valid response' do
        before do
          allow(service).to receive(:get_token).and_return(mock_token_response)
        end

        it 'fetches and caches new token' do
          expect(service.token).to eq('mock_token')
        end
      end

      context 'when get_token returns a blank response' do
        before do
          allow(service).to receive(:get_token).and_return(blank_token_response)
        end

        it 'raises error' do
          expect { service.token }.to raise_error(Eps::BaseService::TokenError, 'Invalid token response')
        end
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

  describe '#get_token' do
    let(:config) { instance_double(Eps::Configuration) }
    let(:jwt_wrapper) { instance_double(Eps::JwtWrapper) }

    before do
      allow(Eps::Configuration).to receive(:instance).and_return(config)
      allow(config).to receive_messages(access_token_url: 'http://test.url', grant_type: 'client_credentials',
                                        scopes: 'test.scope', client_assertion_type: 'urn:test')
      allow(Eps::JwtWrapper).to receive(:new).and_return(jwt_wrapper)
      allow(jwt_wrapper).to receive(:sign_assertion).and_return('signed_jwt')

      allow(service).to receive(:perform).and_return(mock_token_response)
      allow(service).to receive(:with_monitoring).and_yield
    end

    it 'makes POST request with correct parameters' do
      expected_params = URI.encode_www_form({
                                              grant_type: 'client_credentials',
                                              scope: 'test.scope',
                                              client_assertion_type: 'urn:test',
                                              client_assertion: 'signed_jwt'
                                            })

      expect(service).to receive(:perform).with(
        :post,
        'http://test.url',
        expected_params,
        { 'Content-Type' => 'application/x-www-form-urlencoded' }
      )

      service.get_token
    end
  end
end
