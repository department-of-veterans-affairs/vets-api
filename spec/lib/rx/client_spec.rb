# frozen_string_literal: true

require 'rails_helper'
require 'rx/client'
require 'vets/collection'
# Mock upstream request to return source app for Rx client
class UpstreamRequest
  def self.env
    { 'SOURCE_APP' => 'myapp' }
  end
end

describe Rx::Client do
  before(:all) do
    VCR.use_cassette 'rx_client/session' do
      @client ||= begin
        client = Rx::Client.new(session: { user_id: '12210827' },
                                upstream_request: UpstreamRequest)
        client.authenticate
        client
      end
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
    before do
      allow(Settings.mhv.rx).to receive(:collection_caching_enabled).and_return(caching_enabled)
      allow(StatsD).to receive(:increment)
    end

    let(:cache_keys) { ["#{client.session.user_id}:getactiverx", "#{client.session.user_id}:gethistoryrx"] }

    it 'gets a list of active prescriptions' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_active_prescriptions') do
        client_response = client.get_active_rxs
        expect(client_response).to be_a(Vets::Collection)
        expect(client_response.type).to eq(Prescription)
        expect(client_response.cached?).to eq(caching_enabled)

        if caching_enabled
          expect(cache_key_for(client_response)).to eq("#{client.session.user_id}:getactiverx")
        else
          expect(cache_key_for(client_response)).to be_nil
        end
      end
    end

    it 'gets a list of all prescriptions' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions') do
        client_response = client.get_history_rxs
        expect(client_response).to be_a(Vets::Collection)
        expect(client_response.members.first).to be_a(Prescription)
        expect(client_response.cached?).to eq(caching_enabled)

        if caching_enabled
          expect(cache_key_for(client_response)).to eq("#{client.session.user_id}:gethistoryrx")
        else
          expect(cache_key_for(client_response)).to be_nil
        end
      end
    end

    it 'gets a single prescription' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_single_prescription') do
        expect(client.get_rx(13_650_546)).to be_a(Prescription)
      end
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

    it 'handles failed stations' do
      VCR.use_cassette('rx_client/prescriptions/handles_failed_stations') do
        expect(Rails.logger).to receive(:warn).with(/failed station/).with(/Station-000/)
        client.get_history_rxs
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
    before do
      allow(Settings.mhv.rx).to receive(:use_new_api).and_return(use_new_api)
      allow(Settings.mhv_mobile.rx).to receive(:x_api_key).and_return('fake-x-api-key')
      allow(client).to receive(:config).and_return(OpenStruct.new(base_request_headers: { 'base-header' => 'value' },
                                                                  app_token: 'test-app-token'))
      allow(client).to receive(:config).and_return(OpenStruct.new(base_request_headers: { 'base-header' => 'value' },
                                                                  app_token: 'test-app-token',
                                                                  x_api_key: 'fake-x-api-key'))
    end

    describe '#auth_headers' do
      let(:use_new_api) { true }

      it 'returns headers with appToken and mhvCorrelationId' do
        result = client.send(:auth_headers)
        expect(result).to include('x-api-key' => 'fake-x-api-key')
      end
    end

    describe '#get_headers' do
      let(:headers) { { 'custom-header' => 'value' } }

      context 'when use_new_api is true' do
        let(:use_new_api) { true }

        it 'adds x-api-key to headers' do
          result = client.send(:get_headers, headers)
          expect(result).to include('custom-header' => 'value', 'x-api-key' => 'fake-x-api-key')
        end
      end

      context 'when use_new_api is false' do
        let(:use_new_api) { false }

        it 'returns headers without x-api-key' do
          result = client.send(:get_headers, headers)
          expect(result).to eq(headers)
        end
      end
    end

    describe '#get_path' do
      context 'when use_new_api is true' do
        let(:use_new_api) { true }

        it 'returns path with pharmacy/ess' do
          result = client.send(:get_path, 'test-endpoint')
          expect(result).to eq('pharmacy/ess/test-endpoint')
        end
      end

      context 'when use_new_api is false' do
        let(:use_new_api) { false }

        it 'returns path with prescription' do
          result = client.send(:get_path, 'test-endpoint')
          expect(result).to eq('prescription/test-endpoint')
        end
      end
    end
  end

  def cache_key_for(collection)
    collection.instance_variable_get(:@cache_key)
  end
end
