# frozen_string_literal: true

require 'rails_helper'

# Test class to include the TokenAuthentication concern
class TestTokenService < VAOS::SessionService
  include TokenAuthentication
  include Common::Client::Concerns::Monitoring

  # Define needed Redis configuration
  STATSD_KEY_PREFIX = 'api.test'
  REDIS_TOKEN_KEY = 'test-access-token'
  REDIS_TOKEN_TTL = 840

  attr_reader :config, :settings, :user

  # Define token configuration and require a user
  def initialize(user)
    super(user)
    @user = user
    @config = OpenStruct.new(
      access_token_url: 'https://login.wellhive.com/oauth2/default/v1/token',
      grant_type: 'client_credentials',
      scopes: 'test.scope',
      client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
      request_types: [:post],
      base_path: 'https://test.example.com',
      service_name: 'TestService'
    )

    @settings = OpenStruct.new(
      key_path: Rails.root.join('modules', 'vaos', 'spec', 'fixtures', 'test_key.pem').to_s,
      client_id: 'test-client-id',
      kid: 'test-key-id',
      audience_claim_url: 'https://test.example.com/token'
    )
  end

  private

  # Override jwt_wrapper to return a stub that always returns a test signature
  def jwt_wrapper
    @jwt_wrapper ||= OpenStruct.new(sign_assertion: 'test-jwt-assertion')
  end

  # Setup a connection to fetch the token
  def connection
    @connection ||= Faraday.new(config.base_path, request: request_options) do |conn|
      conn.request :camelcase
      conn.request :json
      conn.response :snakecase
      conn.response :json, content_type: /\bjson$/
      conn.adapter Faraday.default_adapter
    end
  end

  # Connection options
  def request_options
    {
      open_timeout: 10,
      timeout: 15
    }
  end
end

RSpec.describe TokenAuthentication do
  # Set up memory store for testing
  subject { TestTokenService.new(user) }

  let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

  let(:user) { build(:user, :loa3) }
  let(:request_id) { '123456-abcdef' }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
    RequestStore.store['request_id'] = request_id
  end

  describe '#headers' do
    it 'returns headers with authorization token' do
      VCR.use_cassette('vaos/concerns/token/token_200', match_requests_on: %i[method path]) do
        expect(subject.headers).to eq(
          'Authorization' => 'Bearer test-access-token',
          'Content-Type' => 'application/json',
          'X-Request-ID' => request_id
        )
      end
    end
  end

  describe '#token' do
    it 'fetches and caches the token' do
      expect(Rails.cache).to receive(:fetch)
        .with(TestTokenService::REDIS_TOKEN_KEY, expires_in: TestTokenService::REDIS_TOKEN_TTL)
        .and_call_original

      VCR.use_cassette('vaos/concerns/token/token_200', match_requests_on: %i[method path]) do
        token = subject.token
        expect(token).to eq('test-access-token')
      end
    end

    it 'reuses cached token' do
      Rails.cache.write(TestTokenService::REDIS_TOKEN_KEY, 'cached-token')
      expect(subject.token).to eq('cached-token')
    end
  end

  describe '#get_token' do
    it 'makes a POST request to fetch token' do
      VCR.use_cassette('vaos/concerns/token/token_200', match_requests_on: %i[method path]) do
        response = subject.get_token
        expect(response.body[:access_token]).to eq('test-access-token')
      end
    end

    it 'handles token request failures' do
      VCR.use_cassette('vaos/concerns/token/token_400', match_requests_on: %i[method path]) do
        response = subject.get_token
        expect(response.status).to eq(400)
      end
    end
  end

  describe '#parse_token_response' do
    context 'with valid response' do
      it 'returns the access token' do
        VCR.use_cassette('vaos/concerns/token/token_200', match_requests_on: %i[method path]) do
          response = subject.get_token
          token = subject.send(:parse_token_response, response)
          expect(token).to eq('test-access-token')
        end
      end
    end

    context 'with invalid response' do
      let(:invalid_response) { OpenStruct.new(body: nil) }

      it 'raises TokenError when response body is nil' do
        expect { subject.send(:parse_token_response, invalid_response) }
          .to raise_error(TokenAuthentication::TokenError, 'Invalid token response')
      end

      it 'raises TokenError when access_token is blank' do
        invalid_response.body = { access_token: '' }
        expect { subject.send(:parse_token_response, invalid_response) }
          .to raise_error(TokenAuthentication::TokenError, 'Invalid token response')
      end
    end
  end
end
