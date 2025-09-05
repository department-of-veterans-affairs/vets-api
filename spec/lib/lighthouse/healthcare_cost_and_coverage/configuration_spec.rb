# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::HealthcareCostAndCoverage::Configuration do
  let(:settings) do
    double(
      host: 'https://test-api.va.gov',
      timeout: 30,
      use_mocks: false,
      access_token: double(
        client_id: 'client_id',
        rsa_key: 'rsa_key',
        aud_claim_url: 'aud_claim_url'
      ),
      scopes: ['scope1']
    )
  end

  subject(:config) { described_class.new }

  before do
    allow(Settings).to receive_message_chain(:lighthouse, :healthcare_cost_and_coverage).and_return(settings)
    allow(Settings).to receive_message_chain(:betamocks, :recording).and_return(false)
  end

  describe '#settings' do
    it 'returns the correct settings' do
      expect(config.settings).to eq(settings)
    end
  end

  describe '#base_path' do
    it 'returns the default host' do
      expect(config.base_path).to eq('https://test-api.va.gov')
    end

    it 'returns the provided host if given' do
      expect(config.base_path('https://other-host')).to eq('https://other-host')
    end
  end

  describe '#base_api_path' do
    it 'returns the full API path' do
      expect(config.base_api_path).to eq('https://sandbox-api.va.gov/services/health-care-costs-coverage/v0')
    end
  end

  describe '#service_name' do
    it 'returns the service name' do
      expect(config.service_name).to eq('HealthcareCostAndCoverage')
    end
  end

  describe '#get' do
    it 'calls connection.get with correct headers' do
      conn = double
      expect(config).to receive(:connection).and_return(conn)
      expect(config).to receive(:access_token).and_return('token')
      expect(conn).to receive(:get).with('/foo', {}, hash_including('Authorization' => 'Bearer token'))
      config.get('/foo')
    end
  end

  describe '#post' do
    it 'calls connection.post with correct headers' do
      conn = double
      expect(config).to receive(:connection).and_return(conn)
      expect(config).to receive(:access_token).and_return('token')
      expect(conn).to receive(:post).with('/foo', { bar: 1 }, hash_including('Authorization' => 'Bearer token'))
      config.post('/foo', { bar: 1 })
    end
  end

  describe '#auth_params' do
    it 'raises if icn is missing' do
      expect { config.send(:auth_params, {}) }.to raise_error(ArgumentError)
    end

    it 'returns base64 encoded launch param if icn is present' do
      result = config.send(:auth_params, icn: '12345')
      decoded = JSON.parse(Base64.decode64(result[:launch]))
      expect(decoded['patient']).to eq('12345')
    end
  end

  describe '#token_service' do
    it 'returns an Auth::ClientCredentials::Service instance' do
      stub_const('Auth::ClientCredentials::Service', Class.new)
      service = config.send(:token_service, nil, nil)
      expect(service).to be_a(Auth::ClientCredentials::Service)
    end
  end
end
