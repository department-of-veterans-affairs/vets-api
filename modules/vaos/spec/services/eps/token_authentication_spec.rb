# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/eps/token_authentication'

# Test class to include the Eps::TokenAuthentication module
class EpsTestTokenService < VAOS::SessionService
  include Eps::TokenAuthentication
  include Common::Client::Concerns::Monitoring

  # Define needed Redis configuration
  STATSD_KEY_PREFIX = 'api.eps'
  REDIS_TOKEN_KEY = 'eps-access-token'
  REDIS_TOKEN_TTL = 840

  attr_reader :config, :settings, :user

  # Define token configuration and require a user
  def initialize(user)
    super(user)
    @user = user
    @config = OpenStruct.new(
      access_token_url: 'https://login.wellhive.com/oauth2/default/v1/token',
      grant_type: 'client_credentials',
      scopes: 'eps.scope',
      client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
      request_types: [:post],
      base_path: 'https://eps.example.com',
      service_name: 'EpsService'
    )

    @settings = OpenStruct.new(
      key_path: Rails.root.join('modules', 'vaos', 'spec', 'fixtures', 'test_key.pem').to_s,
      client_id: 'eps-client-id',
      kid: 'eps-key-id',
      audience_claim_url: 'https://eps.example.com/token'
    )
  end

  # Method needed by module but not under test
  def output_curl_equivalent(url, headers)
    # Do nothing for testing
  end

  private

  # Override jwt_wrapper to return a stub that always returns a test signature
  def jwt_wrapper
    @jwt_wrapper ||= OpenStruct.new(sign_assertion: 'eps-jwt-assertion')
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
    RequestStore.store['controller_name'] = 'VAOS::V2::AppointmentsController'
  end

  describe '#headers_with_correlation_id' do
    let(:logger) { instance_double(Logger) }

    before do
      allow(Rails).to receive(:logger).and_return(logger)
      allow(logger).to receive(:info)
    end

    it 'returns headers with authorization token, request ID, and parent request ID' do
      VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
        headers = subject.headers_with_correlation_id

        expect(headers).to include(
          'Authorization' => 'Bearer test-access-token',
          'Content-Type' => 'application/json',
          'X-Parent-Request-ID' => request_id
        )
        expect(headers).to have_key('X-Request-ID')
        expect(headers['X-Request-ID']).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end
    end

    it 'generates a unique correlation ID for each call' do
      VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
        headers1 = subject.headers_with_correlation_id
        headers2 = subject.headers_with_correlation_id

        expect(headers1['X-Request-ID']).not_to eq(headers2['X-Request-ID'])
      end
    end

    it 'logs the correlation ID and request ID' do
      VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
        subject.headers_with_correlation_id

        expect(logger).to have_received(:info).with(
          hash_including(
            message: 'EPS API Call',
            correlation_id: match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/),
            request_id:
          )
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
      Rails.cache.write(EpsTestTokenService::REDIS_TOKEN_KEY, 'cached-eps-token')
      expect(subject.token).to eq('cached-eps-token')
    end
  end

  describe '#get_token' do
    it 'makes a POST request to fetch token' do
      VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
        response = subject.get_token
        expect(response.body[:access_token]).to eq('test-access-token')
      end
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
      expect(params_string).to include('scope=eps.scope')

      # Break up the long line
      auth_type_param = 'client_assertion_type='
      encoded_value = 'urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer'
      expect(params_string).to include("#{auth_type_param}#{encoded_value}")

      expect(params_string).to include('client_assertion=eps-jwt-assertion')
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
      expect(headers).to include('kid' => 'eps-key-id')
    end
  end

  describe '#parse_token_response' do
    context 'with valid response' do
      it 'returns the access token' do
        VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
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
      expect(jwt_wrapper.sign_assertion).to eq('eps-jwt-assertion')
    end
  end
end
