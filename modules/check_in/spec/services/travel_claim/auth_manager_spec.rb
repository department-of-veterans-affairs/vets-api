# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::AuthManager do
  let(:icn) { '1234567890V123456' }
  let(:station_number) { '500' }
  let(:facility_type) { nil }
  let(:correlation_id) { 'test-correlation-id' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  let(:auth_manager) do
    described_class.new(
      icn:,
      station_number:,
      facility_type:,
      correlation_id:
    )
  end

  # Settings constants
  let(:auth_url) { 'https://login.microsoftonline.us' }
  let(:tenant_id) { 'fake_tenant_id' }
  let(:travel_pay_client_id) { 'fake_client_id' }
  let(:travel_pay_client_secret) { 'fake_client_secret' }
  let(:travel_pay_client_secret_oh) { 'fake_client_secret_oh' }
  let(:travel_pay_resource) { 'fake_resource' }
  let(:claims_url_v2) { 'https://dev.integration.d365.va.gov' }
  let(:client_number) { 'fake_client_number' }
  let(:client_secret) { 'fake_client_secret' }
  let(:subscription_key) { 'sub-key' }
  let(:e_subscription_key) { 'e-sub' }
  let(:s_subscription_key) { 's-sub' }

  let(:veis_response) do
    instance_double(Faraday::Response, body: { 'access_token' => 'veis-token' }, status: 200)
  end
  let(:btsss_response) do
    instance_double(Faraday::Response, body: { 'data' => { 'accessToken' => 'btsss-token' } }, status: 200)
  end

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
    allow(Flipper).to receive(:enabled?).with(:check_in_experience_travel_claim_logging).and_return(false)
  end

  def stub_connections(_manager = nil, veis_resp: veis_response, btsss_resp: btsss_response)
    veis_conn = instance_double(Faraday::Connection)
    btsss_conn = instance_double(Faraday::Connection)
    config_instance = instance_double(TravelClaim::Configuration)

    # Stub config.connection to return different connections based on server_url argument
    allow(config_instance).to receive(:connection).with(no_args).and_return(btsss_conn)
    allow(config_instance).to receive(:connection).with(server_url: anything).and_return(veis_conn)

    allow(TravelClaim::Configuration).to receive(:instance).and_return(config_instance)
    allow(veis_conn).to receive(:post).and_return(veis_resp)
    allow(btsss_conn).to receive(:post).and_return(btsss_resp)
  end

  describe '#initialize' do
    it 'accepts icn, station_number, facility_type, and correlation_id' do
      manager = described_class.new(
        icn: '123',
        station_number: '500',
        facility_type: 'oh',
        correlation_id: 'abc-123'
      )

      expect(manager.station_number).to eq('500')
      expect(manager.facility_type).to eq('oh')
      expect(manager.correlation_id).to eq('abc-123')
    end
  end

  describe '#with_auth' do
    it 'ensures tokens are fetched before yielding' do
      stub_connections(auth_manager)

      result = auth_manager.with_auth { 'success' }

      expect(result).to eq('success')
      expect(auth_manager.send(:instance_variable_get, :@current_veis_token)).to eq('veis-token')
      expect(auth_manager.send(:instance_variable_get, :@current_btsss_token)).to eq('btsss-token')
    end

    context 'when a 401 error occurs' do
      let(:unauthorized_error) do
        Common::Exceptions::BackendServiceException.new('VA900', { detail: 'Unauthorized' }, 401)
      end

      it 'retries once by refreshing all tokens' do
        stub_connections(auth_manager)

        call_count = 0
        result = auth_manager.with_auth do
          call_count += 1
          raise unauthorized_error if call_count == 1

          'success after retry'
        end

        expect(result).to eq('success after retry')
        expect(call_count).to eq(2)
      end

      it 'does not retry more than once' do
        stub_connections(auth_manager)

        call_count = 0

        expect do
          auth_manager.with_auth do
            call_count += 1
            raise unauthorized_error
          end
        end.to raise_error(Common::Exceptions::BackendServiceException)

        expect(call_count).to eq(2)
      end
    end

    context 'when a 409 error occurs' do
      let(:conflict_error) do
        Common::Exceptions::BackendServiceException.new(
          'VA900',
          { detail: 'Conflict error from BTSSS' },
          409
        )
      end

      it 'retries once by refreshing only the BTSSS token' do
        stub_connections(auth_manager)

        original_veis_token = nil
        call_count = 0

        auth_manager.with_auth do
          call_count += 1
          original_veis_token ||= auth_manager.send(:instance_variable_get, :@current_veis_token)
          raise conflict_error if call_count == 1

          'success after retry'
        end

        # VEIS token should be the same (not refreshed)
        expect(auth_manager.send(:instance_variable_get, :@current_veis_token)).to eq(original_veis_token)
        expect(call_count).to eq(2)
      end

      it 'does not retry more than once on 409' do
        stub_connections(auth_manager)

        call_count = 0

        expect do
          auth_manager.with_auth do
            call_count += 1
            raise conflict_error
          end
        end.to raise_error(Common::Exceptions::BackendServiceException)

        expect(call_count).to eq(2)
      end
    end

    context 'when a non-retryable error occurs' do
      it 'raises immediately without retry for 500 errors' do
        stub_connections(auth_manager)

        server_error = Common::Exceptions::BackendServiceException.new(
          'VA900',
          { detail: 'Server error' },
          500
        )
        call_count = 0

        expect do
          auth_manager.with_auth do
            call_count += 1
            raise server_error
          end
        end.to raise_error(Common::Exceptions::BackendServiceException)

        expect(call_count).to eq(1)
      end
    end
  end

  describe '#auth_headers' do
    before do
      auth_manager.instance_variable_set(:@current_veis_token, 'veis-token')
      auth_manager.instance_variable_set(:@current_btsss_token, 'btsss-token')
    end

    it 'returns headers with both tokens' do
      allow(Settings).to receive(:vsp_environment).and_return('staging')
      allow(auth_manager).to receive(:subscription_key_headers).and_return({ 'Ocp-Apim-Subscription-Key' => 'key' })

      headers = auth_manager.auth_headers

      expect(headers['Authorization']).to eq('Bearer veis-token')
      expect(headers['BTSSS-Access-Token']).to eq('btsss-token')
      expect(headers['Content-Type']).to eq('application/json')
      expect(headers['X-Correlation-ID']).to eq(correlation_id)
    end

    it 'includes subscription key for non-production' do
      # Settings are loaded at initialization - use actual test.yml values
      headers = auth_manager.auth_headers

      expect(headers['Ocp-Apim-Subscription-Key']).to eq('fake_subscription_key')
    end

    context 'when in production environment' do
      let(:production_settings) do
        double(
          travel_pay_client_id: 'fake_travel_pay_client_id',
          client_secret: 'fake_client_secret',
          travel_pay_resource: 'fake_travel_pay_resource',
          tenant_id: 'fake_tenant_id',
          auth_url: 'https://login.microsoftonline.us',
          travel_pay_client_secret_oh: 'fake_travel_pay_client_secret_oh',
          travel_pay_client_secret: 'fake_travel_pay_client_secret',
          client_number: 'fake_client_number',
          e_subscription_key:,
          s_subscription_key:
        )
      end

      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
        allow(Settings.check_in).to receive(:travel_reimbursement_api_v2).and_return(production_settings)
      end

      it 'includes separate E and S keys for production' do
        production_manager = described_class.new(
          icn:,
          station_number:,
          facility_type:,
          correlation_id:
        )
        stub_connections(production_manager)
        # Set tokens so auth_headers doesn't raise
        production_manager.instance_variable_set(:@current_veis_token, 'veis-token')
        production_manager.instance_variable_set(:@current_btsss_token, 'btsss-token')

        headers = production_manager.auth_headers

        expect(headers['Ocp-Apim-Subscription-Key-E']).to eq(e_subscription_key)
        expect(headers['Ocp-Apim-Subscription-Key-S']).to eq(s_subscription_key)
      end
    end

    it 'raises error when tokens are not present' do
      auth_manager.instance_variable_set(:@current_veis_token, nil)

      expect do
        auth_manager.auth_headers
      end.to raise_error(TravelClaim::Errors::InvalidArgument, /Missing auth tokens/)
    end
  end

  describe '#refresh_btsss_token! (private)' do
    it 'clears and re-fetches only the BTSSS token' do
      auth_manager.instance_variable_set(:@current_veis_token, 'original-veis-token')
      auth_manager.instance_variable_set(:@current_btsss_token, 'old-btsss-token')

      btsss_conn = instance_double(Faraday::Connection)
      config_instance = instance_double(TravelClaim::Configuration, connection: btsss_conn)
      allow(TravelClaim::Configuration).to receive(:instance).and_return(config_instance)
      allow(btsss_conn).to receive(:post).and_return(
        instance_double(Faraday::Response, body: { 'data' => { 'accessToken' => 'new-btsss-token' } })
      )

      auth_manager.send(:refresh_btsss_token!)

      expect(auth_manager.send(:instance_variable_get, :@current_veis_token)).to eq('original-veis-token')
      expect(auth_manager.send(:instance_variable_get, :@current_btsss_token)).to eq('new-btsss-token')
    end
  end

  describe '#refresh_all_tokens! (private)' do
    it 'clears and re-fetches both tokens' do
      auth_manager.instance_variable_set(:@current_veis_token, 'old-veis-token')
      auth_manager.instance_variable_set(:@current_btsss_token, 'old-btsss-token')

      veis_conn = instance_double(Faraday::Connection)
      btsss_conn = instance_double(Faraday::Connection)
      config_instance = instance_double(TravelClaim::Configuration)
      allow(config_instance).to receive(:connection).with(no_args).and_return(btsss_conn)
      allow(config_instance).to receive(:connection).with(server_url: anything).and_return(veis_conn)
      allow(TravelClaim::Configuration).to receive(:instance).and_return(config_instance)
      allow(veis_conn).to receive(:post).and_return(
        instance_double(Faraday::Response, body: { 'access_token' => 'new-veis-token' })
      )
      allow(btsss_conn).to receive(:post).and_return(
        instance_double(Faraday::Response, body: { 'data' => { 'accessToken' => 'new-btsss-token' } })
      )

      auth_manager.send(:refresh_all_tokens!)

      expect(auth_manager.send(:instance_variable_get, :@current_veis_token)).to eq('new-veis-token')
      expect(auth_manager.send(:instance_variable_get, :@current_btsss_token)).to eq('new-btsss-token')
    end
  end

  describe '#veis_token' do
    it 'returns cached token from Rails.cache' do
      Rails.cache.write(
        'token',
        'cached-token',
        namespace: 'check-in-veis-token-cache-v1'
      )

      expect(auth_manager.veis_token).to eq('cached-token')
    end

    it 'fetches new token when cache is empty' do
      veis_conn = instance_double(Faraday::Connection)
      config_instance = instance_double(TravelClaim::Configuration)
      allow(config_instance).to receive(:connection).with(server_url: anything).and_return(veis_conn)
      allow(TravelClaim::Configuration).to receive(:instance).and_return(config_instance)
      allow(veis_conn).to receive(:post).and_return(veis_response)

      token = auth_manager.veis_token
      expect(token).to eq('veis-token')
    end

    it 'caches the token after fetching' do
      veis_conn = instance_double(Faraday::Connection)
      config_instance = instance_double(TravelClaim::Configuration)
      allow(config_instance).to receive(:connection).with(server_url: anything).and_return(veis_conn)
      allow(TravelClaim::Configuration).to receive(:instance).and_return(config_instance)
      allow(veis_conn).to receive(:post).and_return(veis_response)

      auth_manager.veis_token

      cached = Rails.cache.read(
        'token',
        namespace: 'check-in-veis-token-cache-v1'
      )
      expect(cached).to eq('veis-token')
    end
  end

  describe '#btsss_token' do
    it 'fetches VEIS token first if not present' do
      stub_connections(auth_manager)

      token = auth_manager.btsss_token

      expect(auth_manager.send(:instance_variable_get, :@current_veis_token)).to eq('veis-token')
      expect(token).to eq('btsss-token')
    end

    it 'returns existing token if already fetched' do
      auth_manager.instance_variable_set(:@current_btsss_token, 'existing-token')

      expect(auth_manager.btsss_token).to eq('existing-token')
    end
  end

  describe 'BTSSS client secret selection' do
    # Test values from config/settings/test.yml
    let(:oh_secret) { 'fake_travel_pay_client_secret_oh' }
    let(:standard_secret) { 'fake_travel_pay_client_secret' }

    context 'when facility_type is "oh"' do
      let(:facility_type) { 'oh' }

      it 'uses the Oracle Health client secret' do
        auth_manager.instance_variable_set(:@current_veis_token, 'veis-token')

        btsss_conn = instance_double(Faraday::Connection)
        config_instance = instance_double(TravelClaim::Configuration, connection: btsss_conn)
        allow(TravelClaim::Configuration).to receive(:instance).and_return(config_instance)

        expect(btsss_conn).to receive(:post) do |_path, body, _headers|
          expect(body[:secret]).to eq(oh_secret)
          btsss_response
        end

        auth_manager.btsss_token
      end
    end

    context 'when facility_type is not "oh"' do
      let(:facility_type) { 'vamc' }

      it 'uses the standard client secret' do
        auth_manager.instance_variable_set(:@current_veis_token, 'veis-token')

        btsss_conn = instance_double(Faraday::Connection)
        config_instance = instance_double(TravelClaim::Configuration, connection: btsss_conn)
        allow(TravelClaim::Configuration).to receive(:instance).and_return(config_instance)

        expect(btsss_conn).to receive(:post) do |_path, body, _headers|
          expect(body[:secret]).to eq(standard_secret)
          btsss_response
        end

        auth_manager.btsss_token
      end
    end

    context 'when facility_type is nil (default)' do
      # Uses the top-level let(:facility_type) { nil }

      it 'falls back to the standard client secret' do
        auth_manager.instance_variable_set(:@current_veis_token, 'veis-token')

        btsss_conn = instance_double(Faraday::Connection)
        config_instance = instance_double(TravelClaim::Configuration, connection: btsss_conn)
        allow(TravelClaim::Configuration).to receive(:instance).and_return(config_instance)

        expect(btsss_conn).to receive(:post) do |_path, body, _headers|
          expect(body[:secret]).to eq(standard_secret)
          btsss_response
        end

        auth_manager.btsss_token
      end
    end

    context 'when facility_type is uppercase "OH"' do
      let(:facility_type) { 'OH' }

      it 'uses the Oracle Health client secret' do
        auth_manager.instance_variable_set(:@current_veis_token, 'veis-token')

        btsss_conn = instance_double(Faraday::Connection)
        config_instance = instance_double(TravelClaim::Configuration, connection: btsss_conn)
        allow(TravelClaim::Configuration).to receive(:instance).and_return(config_instance)

        expect(btsss_conn).to receive(:post) do |_path, body, _headers|
          expect(body[:secret]).to eq(oh_secret)
          btsss_response
        end

        auth_manager.btsss_token
      end
    end

    context 'when facility_type is uppercase "VAMC"' do
      let(:facility_type) { 'VAMC' }

      it 'uses the standard client secret' do
        auth_manager.instance_variable_set(:@current_veis_token, 'veis-token')

        btsss_conn = instance_double(Faraday::Connection)
        config_instance = instance_double(TravelClaim::Configuration, connection: btsss_conn)
        allow(TravelClaim::Configuration).to receive(:instance).and_return(config_instance)

        expect(btsss_conn).to receive(:post) do |_path, body, _headers|
          expect(body[:secret]).to eq(standard_secret)
          btsss_response
        end

        auth_manager.btsss_token
      end
    end

    context 'when facility_type contains extra whitespace around "oh"' do
      let(:facility_type) { '  oh  ' }

      it 'uses the Oracle Health client secret' do
        auth_manager.instance_variable_set(:@current_veis_token, 'veis-token')

        btsss_conn = instance_double(Faraday::Connection)
        config_instance = instance_double(TravelClaim::Configuration, connection: btsss_conn)
        allow(TravelClaim::Configuration).to receive(:instance).and_return(config_instance)

        expect(btsss_conn).to receive(:post) do |_path, body, _headers|
          expect(body[:secret]).to eq(oh_secret)
          btsss_response
        end

        auth_manager.btsss_token
      end
    end

    context 'when facility_type is an unexpected type (integer)' do
      let(:facility_type) { 123 }

      it 'falls back to the standard client secret' do
        auth_manager.instance_variable_set(:@current_veis_token, 'veis-token')

        btsss_conn = instance_double(Faraday::Connection)
        config_instance = instance_double(TravelClaim::Configuration, connection: btsss_conn)
        allow(TravelClaim::Configuration).to receive(:instance).and_return(config_instance)

        expect(btsss_conn).to receive(:post) do |_path, body, _headers|
          expect(body[:secret]).to eq(standard_secret)
          btsss_response
        end

        auth_manager.btsss_token
      end
    end

    context 'when facility_type is a symbol :oh' do
      let(:facility_type) { :oh }

      it 'uses the Oracle Health client secret' do
        auth_manager.instance_variable_set(:@current_veis_token, 'veis-token')

        btsss_conn = instance_double(Faraday::Connection)
        config_instance = instance_double(TravelClaim::Configuration, connection: btsss_conn)
        allow(TravelClaim::Configuration).to receive(:instance).and_return(config_instance)

        expect(btsss_conn).to receive(:post) do |_path, body, _headers|
          expect(body[:secret]).to eq(oh_secret)
          btsss_response
        end

        auth_manager.btsss_token
      end
    end
  end

  describe 'error handling' do
    it 'raises BackendServiceException when VEIS token is missing from response' do
      veis_conn = instance_double(Faraday::Connection)
      config_instance = instance_double(TravelClaim::Configuration)
      allow(config_instance).to receive(:connection).with(server_url: anything).and_return(veis_conn)
      allow(TravelClaim::Configuration).to receive(:instance).and_return(config_instance)
      allow(veis_conn).to receive(:post).and_return(
        instance_double(Faraday::Response, body: {})
      )

      expect do
        auth_manager.veis_token
      end.to raise_error(Common::Exceptions::BackendServiceException, /VEIS auth response missing/)
    end

    it 'raises BackendServiceException when BTSSS token is missing from response' do
      auth_manager.instance_variable_set(:@current_veis_token, 'veis-token')

      btsss_conn = instance_double(Faraday::Connection)
      config_instance = instance_double(TravelClaim::Configuration, connection: btsss_conn)
      allow(TravelClaim::Configuration).to receive(:instance).and_return(config_instance)
      allow(btsss_conn).to receive(:post).and_return(
        instance_double(Faraday::Response, body: { 'data' => {} })
      )

      expect do
        auth_manager.btsss_token
      end.to raise_error(Common::Exceptions::BackendServiceException, /BTSSS auth response missing/)
    end
  end
end
