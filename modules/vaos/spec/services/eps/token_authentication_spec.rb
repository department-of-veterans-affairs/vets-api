# frozen_string_literal: true

require 'rails_helper'
require 'eps/token_authentication'

# Test class to include the Eps::TokenAuthentication module
class EpsTestTokenService < VAOS::SessionService
  include Eps::TokenAuthentication
  include Common::Client::Concerns::Monitoring

  # Define needed Redis configuration
  STATSD_KEY_PREFIX = 'api.eps.test'
  REDIS_TOKEN_KEY = 'eps-test-access-token'
  REDIS_TOKEN_TTL = 840

  attr_reader :config, :settings, :user

  # Define token configuration and require a user
  def initialize(user)
    super(user)
    @user = user
    @config = OpenStruct.new(
      access_token_url: 'https://login.wellhive.com/oauth2/default/v1/token',
      grant_type: 'client_credentials',
      scopes: 'care-nav',
      client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
      request_types: [:post],
      base_path: 'https://eps-test.example.com',
      service_name: 'EPSTestService'
    )

    @settings = OpenStruct.new(
      key_path: Rails.root.join('modules', 'vaos', 'spec', 'fixtures', 'test_key.pem').to_s,
      client_id: 'test-client-id',
      kid: 'test-key-id',
      audience_claim_url: 'https://test.example.com/token'
    )
  end

  # Method needed by module but not under test
  def output_curl_equivalent(url, headers)
    # Do nothing for testing
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

RSpec.describe Eps::TokenAuthentication do
  # Set up memory store for testing
  subject { EpsTestTokenService.new(user) }

  let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }
  let(:user) { build(:user, :loa3) }
  let(:request_id) { '123456-abcdef' }
  let(:token_service) { EpsTestTokenService.new(user) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
    RequestStore.store['request_id'] = request_id
  end

  describe '#headers' do
    it 'returns headers with authorization token' do
      VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
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
        .with(EpsTestTokenService::REDIS_TOKEN_KEY, expires_in: EpsTestTokenService::REDIS_TOKEN_TTL)
        .and_call_original

      VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
        token = subject.token
        expect(token).to eq('test-access-token')
      end
    end

    it 'reuses cached token' do
      Rails.cache.write(EpsTestTokenService::REDIS_TOKEN_KEY, 'cached-token')
      expect(subject.token).to eq('cached-token')
    end
  end

  describe '#get_token' do
    it 'makes a POST request to fetch token with parameters in URL' do
      # Test the approach of appending parameters to URL
      service = token_service

      # Using allow_any_instance_of instead of stubbing subject directly
      allow_any_instance_of(EpsTestTokenService).to receive(:perform) do |_, method, url, body, headers|
        expect(method).to eq(:post)
        expect(url).to include('?grant_type=client_credentials')
        expect(url).to include('scope=care-nav')

        client_assertion_type_param = 'client_assertion_type=urn%3Aietf%3Aparams%3Aoauth'
        expect(url).to include(client_assertion_type_param)

        expect(url).to include('client_assertion=test-jwt-assertion')
        expect(body).to eq('') # Empty string body
        expect(headers).to include('Content-Type' => 'application/x-www-form-urlencoded')
        expect(headers).to include('kid' => 'test-key-id')

        # Return a mock response
        OpenStruct.new(
          status: 200,
          body: { access_token: 'test-access-token', expires_in: 3600 }
        )
      end

      response = service.get_token
      expect(response.body[:access_token]).to eq('test-access-token')
    end

    it 'handles token request failures' do
      VCR.use_cassette('vaos/eps/token/token_400', match_requests_on: %i[method path]) do
        response = subject.get_token
        expect(response.status).to eq(400)
      end
    end
  end

  describe '#token_params_for_url' do
    it 'returns URL-encoded parameters string' do
      params_string = subject.send(:token_params_for_url)
      expect(params_string).to be_a(String)
      expect(params_string).to include('grant_type=client_credentials')
      expect(params_string).to include('scope=care-nav')

      # Break up the long line
      auth_type_param = 'client_assertion_type='
      encoded_value = 'urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer'
      expect(params_string).to include("#{auth_type_param}#{encoded_value}")

      expect(params_string).to include('client_assertion=test-jwt-assertion')
    end

    it 'properly URL-encodes special characters' do
      # Create test service with custom JWT assertion
      service = token_service
      special_jwt_wrapper = OpenStruct.new(sign_assertion: 'test+with@special:characters?&')
      allow(service).to receive(:jwt_wrapper).and_return(special_jwt_wrapper)

      params_string = service.send(:token_params_for_url)
      expect(params_string).to include('client_assertion=test%2Bwith%40special%3Acharacters%3F%26')
    end
  end

  describe '#token_request_headers_for_curl' do
    it 'returns headers for token request' do
      headers = subject.send(:token_request_headers_for_curl)
      expect(headers).to include('Content-Type' => 'application/x-www-form-urlencoded')
      expect(headers).to include('kid' => 'test-key-id')
    end
  end

  describe '#parse_token_response' do
    context 'with valid response' do
      it 'returns the access token' do
        response = OpenStruct.new(
          body: { access_token: 'test-access-token', expires_in: 3600 }
        )

        token = subject.send(:parse_token_response, response)
        expect(token).to eq('test-access-token')
      end
    end

    context 'with invalid response' do
      let(:invalid_response) { OpenStruct.new(body: nil) }

      it 'raises TokenError when response body is nil' do
        expect { subject.send(:parse_token_response, invalid_response) }
          .to raise_error(Eps::TokenAuthentication::TokenError, 'Invalid token response')
      end

      it 'raises TokenError when access_token is blank' do
        invalid_response.body = { access_token: '' }
        expect { subject.send(:parse_token_response, invalid_response) }
          .to raise_error(Eps::TokenAuthentication::TokenError, 'Invalid token response')
      end
    end
  end

  describe '#jwt_wrapper' do
    it 'returns a jwt wrapper instance' do
      jwt_wrapper = subject.send(:jwt_wrapper)
      expect(jwt_wrapper).to respond_to(:sign_assertion)
      expect(jwt_wrapper.sign_assertion).to eq('test-jwt-assertion')
    end
  end
end
