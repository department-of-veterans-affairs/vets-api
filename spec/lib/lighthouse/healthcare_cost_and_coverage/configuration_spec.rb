# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/healthcare_cost_and_coverage/configuration'

RSpec.describe Lighthouse::HealthcareCostAndCoverage::Configuration do
  subject(:config) { described_class.instance }

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

  before do
    allow(Settings.lighthouse).to receive(:healthcare_cost_and_coverage).and_return(settings)
    allow(Settings.betamocks).to receive(:recording).and_return(false)
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
      expect(config.base_api_path).to eq('https://test-api.va.gov/services/health-care-costs-coverage/v0')
    end
  end

  describe '#service_name' do
    it 'returns the service name' do
      expect(config.service_name).to eq('HealthcareCostAndCoverage')
    end
  end

  context 'requests' do
    before do
      allow(Settings.lighthouse).to receive(:healthcare_cost_and_coverage).and_return(settings)
      allow(Settings.betamocks).to receive(:recording).and_return(false)

      config.instance_variable_set(:@token_service, nil)
      config.instance_variable_set(:@conn, nil)
    end

    describe '#get' do
      it 'calls connection.get with correct headers' do
        # fresh token service per example
        svc = double('Auth::ClientCredentials::Service', get_token: 'token')
        allow(Auth::ClientCredentials::Service).to receive(:new).and_return(svc)

        # fresh Faraday connection per example
        conn = double('Faraday::Connection')
        config.instance_variable_set(:@conn, conn)

        expect(conn).to receive(:get).with('/foo', nil, hash_including('Authorization' => 'Bearer token'))
        config.get('/foo', icn: '43000199')
      end
    end

    describe '#post' do
      it 'calls connection.post with correct headers' do
        svc = double('Auth::ClientCredentials::Service', get_token: 'token')
        allow(Auth::ClientCredentials::Service).to receive(:new).and_return(svc)

        conn = double('Faraday::Connection')
        config.instance_variable_set(:@conn, conn)

        expect(conn).to receive(:post).with('/foo', { bar: 1 }, hash_including('Authorization' => 'Bearer token'))
        config.post('/foo', { bar: 1 }, icn: '43000199')
      end
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
end
