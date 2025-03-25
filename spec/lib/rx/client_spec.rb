# frozen_string_literal: true

require 'rails_helper'
require 'rx/client'

# Mock upstream request to return source app for Rx client
class UpstreamRequest
  def self.env
    { 'SOURCE_APP' => 'myapp' }
  end
end

describe Rx::Client do
  let(:client) { @client }

  context 'when :mhv_medications_add_x_api_key flag is enabled' do
    before do
      Settings.mhv.rx.base_path = 'v1/'
      allow(Flipper).to receive(:enabled?).with(:mhv_medications_add_x_api_key).and_return(true)
      VCR.use_cassette 'rx_client/session_gw' do
        @client ||= begin
          client = Rx::Client.new(session: { user_id: '17621060' },
                                  upstream_request: UpstreamRequest)
          client.authenticate
          client
        end
      end
    end

    it 'gets rx preferences' do
      VCR.use_cassette('rx_client/preferences/gets_rx_preferences_gw') do
        client_response = client.get_preferences
        expect(client_response.email_address).to eq('kamyar.karshenas@va.gov')
        expect(client_response.rx_flag).to be(true)
      end
    end

    it 'sets rx preferences' do
      VCR.use_cassette('rx_client/preferences/sets_rx_preferences_gw') do
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
      VCR.use_cassette('rx_client/preferences/raises_a_backend_service_exception_when_email_includes_spaces_gw') do
        expect { client.post_preferences(email_address: 'kamyar karshenas@va.gov', rx_flag: false) }
          .to raise_error(Common::Exceptions::BackendServiceException)
      end
    end

    shared_examples 'prescriptions' do |caching_enabled|
      before do
        allow(Settings.mhv.rx).to receive(:collection_caching_enabled).and_return(caching_enabled)
        allow(StatsD).to receive(:increment)
      end

      let(:cache_keys) { ["#{client.session.user_id}:getactiverx", "#{client.session.user_id}:gethistoryrx"] }

      it 'gets a list of active prescriptions' do
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_active_prescriptions_gw') do
          client_response = client.get_active_rxs
          expect(client_response).to be_a(Common::Collection)
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
        VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions_gw') do
          client_response = client.get_history_rxs
          expect(client_response).to be_a(Common::Collection)
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
        VCR.use_cassette('rx_client/prescriptions/gets_a_single_prescription_gw') do
          expect(client.get_rx(25_343_636)).to be_a(Prescription)
        end
      end

      it 'refills a prescription' do
        VCR.use_cassette('rx_client/prescriptions/refills_a_prescription_gw') do
          if caching_enabled
            expect(Common::Collection).to receive(:bust).with(cache_keys)
          else
            expect(Common::Collection).not_to receive(:bust).with([nil, nil])
          end

          client_response = client.post_refill_rx(25_343_636)
          expect(client_response.status).to equal 200
          # This is what MHV returns, even though we don't care
          expect(client_response.body).to eq(status: 'success')
          expect(StatsD).to have_received(:increment).with(
            "#{described_class::STATSD_KEY_PREFIX}.refills.requested", 1, tags: ['source_app:myapp']
          ).exactly(:once)
        end
      end

      it 'refills multiple prescriptions' do
        VCR.use_cassette('rx_client/prescriptions/refills_multiple_prescriptions_gw') do
          ids = [24_378_220]
          client_response = client.post_refill_rxs(ids)
          expect(client_response.status).to equal 200
          expect(StatsD).to have_received(:increment).with(
            "#{described_class::STATSD_KEY_PREFIX}.refills.requested", ids.size, tags: ['source_app:myapp']
          ).exactly(:once)
        end
      end

      context 'nested resources' do
        it 'gets tracking for a prescription' do
          VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_tracking_for_a_prescription_gw') do
            client_response = client.get_tracking_rx(13_650_541)
            expect(client_response).to be_a(Tracking)
            expect(client_response.prescription_id).to eq(13_650_541)
          end
        end

        it 'gets a list of tracking history for a prescription' do
          VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_a_list_of_tracking_history_for_a_prescription_gw') do
            client_response = client.get_tracking_history_rx(13_650_541)
            expect(client_response).to be_a(Common::Collection)
            expect(client_response.members.first.prescription_id).to eq(13_650_541)
            expect(client_response.cached?).to be(false)
            expect(cache_key_for(client_response)).to be_nil
          end
        end
      end

      it 'handles failed stations' do
        VCR.use_cassette('rx_client/prescriptions/handles_failed_stations_gw') do
          response = client.get_history_rxs

          metadata = response.instance_variable_get(:@metadata)
          expect(metadata[:failed_station_list]).to eq('')
          expect(metadata[:successful_station_list]).to be_nil
        end
      end
    end

    describe 'Prescriptions with caching disabled' do
      it_behaves_like 'prescriptions', false
    end

    describe 'Prescriptions with caching enabled' do
      it_behaves_like 'prescriptions', true
    end
  end

  context 'when :mhv_medications_add_x_api_key flag is disabled' do
    before do
      Settings.mhv.rx.base_path = 'mhv-api/patient/v1/'
      allow(Flipper).to receive(:enabled?).with(:mhv_medications_add_x_api_key).and_return(false)
      VCR.use_cassette 'rx_client/session' do
        @client ||= begin
          client = Rx::Client.new(session: { user_id: '17621060' },
                                  upstream_request: UpstreamRequest)
          client.authenticate
          client
        end
      end
    end

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
      VCR.use_cassette('rx_client/preferences/raises_a_backend_service_exception_when_email_includes_spaces') do
        expect { client.post_preferences(email_address: 'kamyar karshenas@va.gov', rx_flag: false) }
          .to raise_error(Common::Exceptions::BackendServiceException)
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
          expect(client_response).to be_a(Common::Collection)
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
          expect(client_response).to be_a(Common::Collection)
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
          expect(client.get_rx(21_142_513)).to be_a(Prescription)
        end
      end

      it 'refills a prescription' do
        VCR.use_cassette('rx_client/prescriptions/refills_a_prescription') do
          if caching_enabled
            expect(Common::Collection).to receive(:bust).with(cache_keys)
          else
            expect(Common::Collection).not_to receive(:bust).with([nil, nil])
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
          ids = [24_378_220]
          client_response = client.post_refill_rxs(ids)
          expect(client_response.status).to equal 200
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
          VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_a_list_of_tracking_history_for_a_prescription') do
            client_response = client.get_tracking_history_rx(13_650_541)
            expect(client_response).to be_a(Common::Collection)
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
  end

  def cache_key_for(collection)
    collection.instance_variable_get(:@cache_key)
  end
end
