# frozen_string_literal: true

require 'rails_helper'
require 'rx/client'

describe 'rx client' do
  before(:all) do
    VCR.use_cassette 'rx_client/session', record: :new_episodes do
      @client ||= begin
        client = Rx::Client.new(session: { user_id: '12210827' })
        client.authenticate
        client
      end
    end
  end

  let(:client) { @client }

  describe 'preferences' do
    it 'gets rx preferences', :vcr do
      client_response = client.get_preferences
      expect(client_response.email_address).to eq('Praneeth.Gaganapally@va.gov')
      expect(client_response.rx_flag).to eq(true)
    end

    it 'sets rx preferences', :vcr do
      client_response = client.post_preferences(email_address: 'kamyar.karshenas@va.gov', rx_flag: false)
      expect(client_response.email_address).to eq('kamyar.karshenas@va.gov')
      expect(client_response.rx_flag).to eq(false)
      # Change it back to what it was to make this test idempotent
      client_response = client.post_preferences(email_address: 'Praneeth.Gaganapally@va.gov', rx_flag: true)
      expect(client_response.email_address).to eq('Praneeth.Gaganapally@va.gov')
      expect(client_response.rx_flag).to eq(true)
    end

    it 'raises a backend service exception when email includes spaces', :vcr do
      expect { client.post_preferences(email_address: 'kamyar karshenas@va.gov', rx_flag: false) }
        .to raise_error(Common::Exceptions::BackendServiceException)
    end
  end

  describe 'prescriptions' do
    it 'gets a list of active prescriptions', :vcr do
      client_response = client.get_active_rxs
      expect(client_response).to be_a(Common::Collection)
      expect(client_response.members.first).to be_a(Prescription)
    end

    it 'gets a list of all prescriptions', :vcr do
      client_response = client.get_history_rxs
      expect(client_response).to be_a(Common::Collection)
      expect(client_response.members.first).to be_a(Prescription)
    end

    it 'gets a single prescription', :vcr do
      expect(client.get_rx(13_650_546)).to be_a(Prescription)
    end

    it 'refills a prescription', :vcr do
      client_response = client.post_refill_rx(13_650_545)
      expect(client_response.status).to equal 200
      # This is what MHV returns, even though we don't care
      expect(client_response.body).to eq(status: 'success')
    end

    context 'nested resources' do
      it 'gets tracking for a prescription', :vcr do
        client_response = client.get_tracking_rx(13_650_541)
        expect(client_response).to be_a(Tracking)
        expect(client_response.prescription_id).to eq(13_650_541)
      end

      it 'gets a list of tracking history for a prescription', :vcr do
        client_response = client.get_tracking_history_rx(13_650_541)
        expect(client_response).to be_a(Common::Collection)
        expect(client_response.members.first.prescription_id).to eq(13_650_541)
      end
    end

    it 'handles failed stations', :vcr do
      expect(Rails.logger).to receive(:warn).with(/failed station/).with(/Station-000/)
      client.get_history_rxs
    end
  end
end
