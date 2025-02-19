# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/concerns/token_authentication'
require_relative '../../../app/services/concerns/jwt_wrapper'
require 'common/client/concerns/monitoring'

# Test class to include the TokenAuthentication concern
class TestTokenService
  include Concerns::TokenAuthentication
  include Common::Client::Concerns::Monitoring

  # Define needed Redis configuration
  STATSD_KEY_PREFIX = 'api.test'
  REDIS_TOKEN_KEY = 'test-access-token'
  REDIS_TOKEN_TTL = 840

  attr_reader :config

  # Define token configuration
  def initialize
    @config = OpenStruct.new(
      access_token_url: 'https://test.example.com/token',
      grant_type: 'client_credentials',
      scopes: 'test.scope',
      client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
    )
  end

  # Mock stub for perform
  # Note: Perform in session service performs other functions beyond what we need testing
  def perform(method, url, params, headers)
    # Mock implementation for testing
  end
end

RSpec.describe Concerns::TokenAuthentication do
  subject { TestTokenService.new }

  let(:request_id) { '123456-abcdef' }
  let(:jwt_wrapper) { instance_double(Concerns::JwtWrapper, sign_assertion: 'signed-jwt-token') }
  let(:mock_token_response) do
    OpenStruct.new(
      body: {
        'access_token' => 'test-access-token',
        'token_type' => 'Bearer',
        'expires_in' => 3600,
        'scope' => 'test.scope'
      }
    )
  end

  before do
    RequestStore.store['request_id'] = request_id
    allow(Concerns::JwtWrapper).to receive(:new).and_return(jwt_wrapper)
    allow(subject).to receive(:perform).and_return(mock_token_response)
    Rails.cache.clear
  end

  describe '#headers' do
    it 'returns headers with authorization token' do
      allow(subject).to receive(:token).and_return('test-access-token')

      expect(subject.headers).to eq(
        'Authorization' => 'Bearer test-access-token',
        'Content-Type' => 'application/json',
        'X-Request-ID' => request_id
      )
    end
  end

  describe '#token' do
    it 'fetches and caches the token' do
      expect(Rails.cache).to receive(:fetch)
        .with(TestTokenService::REDIS_TOKEN_KEY, expires_in: TestTokenService::REDIS_TOKEN_TTL)
        .and_call_original

      token = subject.token
      expect(token).to eq('test-access-token')
    end

    it 'reuses cached token' do
      expect(Rails.cache).to receive(:fetch)
        .with(TestTokenService::REDIS_TOKEN_KEY, expires_in: TestTokenService::REDIS_TOKEN_TTL)
        .and_return('test-access-token')
      expect(subject).not_to receive(:get_token)
      subject.token
    end
  end

  describe '#get_token' do
    it 'makes a POST request to fetch token' do
      expected_params = URI.encode_www_form(
        grant_type: 'client_credentials',
        scope: 'test.scope',
        client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
        client_assertion: 'signed-jwt-token'
      )

      expect(subject).to receive(:perform).with(
        :post,
        'https://test.example.com/token',
        expected_params,
        { 'Content-Type' => 'application/x-www-form-urlencoded' }
      )

      subject.get_token
    end
  end

  describe '#parse_token_response' do
    context 'with valid response' do
      it 'returns the access token' do
        token = subject.send(:parse_token_response, mock_token_response)
        expect(token).to eq('test-access-token')
      end
    end

    context 'with invalid response' do
      let(:invalid_response) { OpenStruct.new(body: nil) }

      it 'raises TokenError when response body is nil' do
        expect { subject.send(:parse_token_response, invalid_response) }
          .to raise_error(Concerns::TokenAuthentication::TokenError, 'Invalid token response')
      end

      it 'raises TokenError when access_token is blank' do
        invalid_response.body = { 'access_token' => '' }
        expect { subject.send(:parse_token_response, invalid_response) }
          .to raise_error(Concerns::TokenAuthentication::TokenError, 'Invalid token response')
      end
    end
  end
end
