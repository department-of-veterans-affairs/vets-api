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
      @client = Rx::Client.new(session: { user_id: '16955936' },
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

  shared_examples 'prescriptions' do
    before do
      allow(StatsD).to receive(:increment)
    end

    it 'gets a list of active prescriptions' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_active_prescriptions') do
        client_response = client.get_active_rxs
        expect(client_response).to be_a(Vets::Collection)
        expect(client_response.type).to eq(Prescription)
      end
    end

    it 'gets a list of all prescriptions' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions') do
        client_response = client.get_history_rxs
        expect(client_response).to be_a(Vets::Collection)
        expect(client_response.members.first).to be_a(Prescription)
      end
    end

    it 'gets a single prescription' do
      VCR.use_cassette('rx_client/prescriptions/gets_a_single_prescription') do
        expect(client.get_rx(13_650_546)).to be_a(Prescription)
      end
    end

    it 'refills a prescription' do
      VCR.use_cassette('rx_client/prescriptions/refills_a_prescription') do
        client_response = client.post_refill_rx(13_650_545)
        expect(client_response.status).to equal 200
        expect(client_response.body).to eq(status: 'success')
        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY_PREFIX}.refills.requested", 1, tags: ['source_app:myapp']
        ).exactly(:once)
      end
    end

    it 'refills multiple prescriptions' do
      VCR.use_cassette('rx_client/prescriptions/refills_multiple_prescriptions') do
        ids = [25_664_832, 25_658_010]
        client_response = client.post_refill_rxs(ids)
        expect(client_response.status).to equal 200
        # This is what MHV returns for successful multiple refills
        expect(client_response.body).to include(
          :failed_station_list,
          :successful_station_list,
          :last_updated_time,
          :prescription_list,
          :errors,
          :info_messages
        )
        # Verify successful refill indicators
        expect(client_response.body[:successful_station_list]).to be_present
        expect(client_response.body[:errors]).to be_an(Array)
        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY_PREFIX}.refills.requested", ids.size, tags: ['source_app:myapp']
        ).exactly(:once)
      end
    end

    it 'handles failures when refilling multiple prescriptions' do
      VCR.use_cassette('rx_client/prescriptions/refills_multiple_prescriptions_failure') do
        ids = [13_650_545, 13_650_546]
        client_response = client.post_refill_rxs(ids)
        expect(client_response.status).to equal 200
        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY_PREFIX}.refills.requested", ids.size, tags: ['source_app:myapp']
        ).exactly(:once)
        expect(client_response.body).to include(
          :failed_station_list,
          :successful_station_list,
          :last_updated_time,
          :prescription_list,
          :errors,
          :info_messages
        )
        expect(client_response.body[:errors]).to be_an(Array)
        expect(client_response.body[:errors]).not_to be_empty
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

  describe 'API gateway methods' do
    let(:config) { Rx::Configuration.instance }

    before do
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
end
