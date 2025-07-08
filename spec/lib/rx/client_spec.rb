# frozen_string_literal: true

require 'rails_helper'
require 'rx/client'
require 'vets/collection'
require 'rx/configuration'

# Mock upstream request to return source app for Rx client
class UpstreamRequest
  def self.env
    { 'SOURCE_APP' => 'myapp' }
  end
end

describe Rx::Client do
  before do
    VCR.use_cassette 'rx_client/session' do
      @client = Rx::Client.new(session: { user_id: '12210827' },
                               upstream_request: UpstreamRequest)
      @client.authenticate
    end
  end

  let(:client) { @client }

  describe 'preferences' do
    it 'gets rx preferences' do
      VCR.use_cassette('rx_client/preferences/gets_rx_preferences') do
        client_response = client.get_preferences
        expect(client_response.email_address).to eq('Praneeth.Gaganapally@va.gov')
        expect(client_response.rx_flag).to be(true)
      end
    end

    it 'sets rx preferences' do
      VCR.use_cassette('rx_client/preferences/sets_rx_preferences') do
        client_response = client.post_preferences(email_address: 'kamyar.karshenas@va.gov', rx_flag: false)
        expect(client_response.email_address).to eq('kamyar.karshenas@va.gov')
        expect(client_response.rx_flag).to be(false)
        # Change it back to what it was to make this test idempotent
        client_response = client.post_preferences(email_address: 'Praneeth.Gaganapally@va.gov', rx_flag: true)
        expect(client_response.email_address).to eq('Praneeth.Gaganapally@va.gov')
        expect(client_response.rx_flag).to be(true)
      end
    end

    it 'raises a backend service exception when email includes spaces' do
      cassette = 'raises_a_backend_service_exception_when_email_includes_spaces'
      VCR.use_cassette("rx_client/preferences/#{cassette}") do
        expect { client.post_preferences(email_address: 'kamyar karshenas@va.gov', rx_flag: false) }
          .to raise_error(Common::Exceptions::BackendServiceException)
      end
    end
  end

  shared_examples 'prescriptions' do |caching_enabled|
    let(:cache_keys) { ["12210827:medications", "12210827:getactiverx"] }

    before do
      allow(Settings.mhv.rx).to receive(:collection_caching_enabled).and_return(caching_enabled)
      allow(StatsD).to receive(:increment)
    end

    it 'refills a prescription' do
      VCR.use_cassette('rx_client/prescriptions/refills_a_prescription') do
        if caching_enabled
          expect(Vets::Collection).to receive(:bust).with(cache_keys)
        else
          expect(Vets::Collection).not_to receive(:bust).with([nil, nil])
        end

        client_response = client.post_refill_rx(13_650_545)
        expect(client_response.status).to equal 200
        # This is what MHV returns, even though we don't care
        expect(client_response.body).to eq(status: 'success')
        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY_PREFIX}.refills.requested", 1, tags: ['source_app:myapp']
        ).exactly(:once)
      end
    end

    it 'refills multiple prescriptions' do
      VCR.use_cassette('rx_client/prescriptions/refills_multiple_prescriptions') do
        ids = [13_650_545, 13_650_546]
        client_response = client.post_refill_rxs(ids)
        expect(client_response.status).to equal 200
        # This is what MHV returns, even though we don't care
        expect(client_response.body).to eq(status: 'success')
        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY_PREFIX}.refills.requested", ids.size, tags: ['source_app:myapp']
        ).exactly(:once)
      end
    end

    context 'nested resources' do
      it 'gets tracking for a prescription' do
        VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_tracking_for_a_prescription') do
          client_response = client.get_tracking_rx(13_650_541)
          expect(client_response).to be_a(Tracking)
          expect(client_response.prescription_id).to eq(13_650_541)
        end
      end

      it 'gets a list of tracking history for a prescription' do
        cassette = 'gets_a_list_of_tracking_history_for_a_prescription'
        VCR.use_cassette("rx_client/prescriptions/nested_resources/#{cassette}") do
          client_response = client.get_tracking_history_rx(13_650_541)
          expect(client_response).to be_a(Vets::Collection)
          expect(client_response.members.first.prescription_id).to eq(13_650_541)
          expect(client_response.cached?).to be(false)
          expect(cache_key_for(client_response)).to be_nil
        end
      end
    end
  end

  describe 'Prescriptions with caching disabled' do
    it_behaves_like 'prescriptions', false
  end

  describe 'Prescriptions with caching enabled' do
    it_behaves_like 'prescriptions', true
  end

  describe 'Test new API gateway methods' do
    let(:config) { Rx::Configuration.instance }

    context 'when mhv_medications_migrate_to_api_gateway flipper flag is true' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medications_migrate_to_api_gateway).and_return(true)
        allow(Settings.mhv.rx).to receive(:x_api_key).and_return('test-api-key')
      end

      it 'returns the x-api-key header' do
        result = client.send(:auth_headers)
        headers = { 'base-header' => 'value', 'appToken' => 'test-app-token', 'mhvCorrelationId' => '10616687' }
        allow(client).to receive(:auth_headers).and_return(headers)
        expect(result).to include('x-api-key' => 'test-api-key')
        expect(config.x_api_key).to eq('test-api-key')
      end
    end

    context 'when mhv_medications_migrate_to_api_gateway flipper flag is false' do
      it 'returns nil for x-api-key' do
        result = client.send(:auth_headers)
        headers = { 'base-header' => 'value', 'appToken' => 'test-app-token', 'mhvCorrelationId' => '10616687' }
        allow(client).to receive(:auth_headers).and_return(headers)
        expect(result).not_to include('x-api-key')
      end
    end
  end

  describe '#get_active_rxs_with_details' do
    let(:cache_key) { '12210827:getactiverx' }
    let(:prescription_details_hash) do
      h = build(:prescription_details).as_json
      h['tracking_list'] = nil
      h['rx_rf_records'] = nil
      h
    end
    let(:cached_data) { [prescription_details_hash, prescription_details_hash] }
    let(:service_response) do
      {
        data: [prescription_details_hash],
        metadata: { total: 1 },
        errors: nil
      }
    end

    before do
      allow(client).to receive(:cache_key).with('getactiverx').and_return(cache_key)
      allow(StatsD).to receive(:increment)
    end

    context 'when data is cached' do
      before do
        allow(PrescriptionDetails).to receive(:get_cached).with(cache_key).and_return(cached_data)
      end

      it 'returns cached data as a Vets::Collection' do
        result = client.get_active_rxs_with_details
        expect(result).to be_a(Vets::Collection)
        expect(result.members.map(&:as_json)).to eq(cached_data)
        expect(PrescriptionDetails).not_to receive(:set_cached)
        expect(StatsD).to have_received(:increment).with('api.rx.cache.hit')
      end
    end

    context 'when data is not cached' do
      before do
        allow(PrescriptionDetails).to receive(:get_cached).with(cache_key).and_return(nil)
        allow(PrescriptionDetails).to receive(:set_cached)
        allow(client).to receive(:perform).with(:get, 'prescription/getactiverx', nil, anything).and_return(
          double(body: service_response)
        )
      end

      it 'fetches data from the service and caches it' do
        result = client.get_active_rxs_with_details
        expect(result).to be_a(Vets::Collection)
        expect(result.members.map(&:as_json)).to eq(service_response[:data])
        expect(PrescriptionDetails).to have_received(:set_cached).with(cache_key, service_response[:data])
        expect(StatsD).to have_received(:increment).with('api.rx.cache.miss')
      end
    end
  end

  def cache_key_for(collection)
    collection.instance_variable_get(:@cache_key)
  end
end
