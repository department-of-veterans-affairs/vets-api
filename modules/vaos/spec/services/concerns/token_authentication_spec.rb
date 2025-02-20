# frozen_string_literal: true

require 'rails_helper'

# Base class for testing that implements perform
# This is used so we don't have to implement all other functions of the service session class.
class TestServiceBase
  def perform(method, url, params, headers)
    @last_request = OpenStruct.new(
      method: method,
      url: url,
      params: params,
      headers: headers
    )

    # Return mock response for token request
    OpenStruct.new(
      body: {
        'access_token' => 'test-access-token',
        'token_type' => 'Bearer',
        'expires_in' => 3600,
        'scope' => 'test.scope'
      }
    )
  end

  attr_reader :last_request
end

# Test class to include the TokenAuthentication concern
class TestTokenService < TestServiceBase
  include TokenAuthentication
  include Common::Client::Concerns::Monitoring

  # Define needed Redis configuration
  STATSD_KEY_PREFIX = 'api.test'
  REDIS_TOKEN_KEY = 'test-access-token'
  REDIS_TOKEN_TTL = 840

  attr_reader :config

  # Define token configuration
  def initialize
    super()
    @config = OpenStruct.new(
      access_token_url: 'https://test.example.com/token',
      grant_type: 'client_credentials',
      scopes: 'test.scope',
      client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
    )
  end
end

RSpec.describe TokenAuthentication do
  subject { TestTokenService.new }

  let(:request_id) { '123456-abcdef' }
  let(:jwt_wrapper) { instance_double(Common::JwtWrapper, sign_assertion: 'signed-jwt-token') }

  before do
    RequestStore.store['request_id'] = request_id
    allow(Common::JwtWrapper).to receive(:new).and_return(jwt_wrapper)
    Rails.cache.clear
  end

  describe '#headers' do
    it 'returns headers with authorization token' do
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
        .and_return('cached-token')

      expect_any_instance_of(TestServiceBase).not_to receive(:perform)
      expect(subject.token).to eq('cached-token')
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

      subject.get_token
      last_request = subject.last_request

      expect(last_request.method).to eq(:post)
      expect(last_request.url).to eq('https://test.example.com/token')
      expect(last_request.params).to eq(expected_params)
      expect(last_request.headers).to eq('Content-Type' => 'application/x-www-form-urlencoded')
    end
  end

  describe '#parse_token_response' do
    context 'with valid response' do
      it 'returns the access token' do
        response = OpenStruct.new(
          body: {
            'access_token' => 'test-access-token',
            'token_type' => 'Bearer',
            'expires_in' => 3600,
            'scope' => 'test.scope'
          }
        )
        token = subject.send(:parse_token_response, response)
        expect(token).to eq('test-access-token')
      end
    end

    context 'with invalid response' do
      let(:invalid_response) { OpenStruct.new(body: nil) }

      it 'raises TokenError when response body is nil' do
        expect { subject.send(:parse_token_response, invalid_response) }
          .to raise_error(TokenAuthentication::TokenError, 'Invalid token response')
      end

      it 'raises TokenError when access_token is blank' do
        invalid_response.body = { 'access_token' => '' }
        expect { subject.send(:parse_token_response, invalid_response) }
          .to raise_error(TokenAuthentication::TokenError, 'Invalid token response')
      end
    end
  end
end
