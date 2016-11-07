# frozen_string_literal: true
require 'rails_helper'
require 'rx/client'
require 'support/rx_client_helpers'

describe 'rx client' do
  include Rx::ClientHelpers

  describe 'prescriptions' do
    let(:post_refill_error) { File.read('spec/support/fixtures/post_refill_error.json') }

    before(:all) do
      VCR.use_cassette 'rx_client/session', record: :new_episodes do
        @client ||= begin
          client = Rx::Client.new(session: { user_id: ENV['MHV_USER_ID'] })
          client.authenticate
          client
        end
      end
    end

    let(:client) { @client }

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
      client_response = client.post_refill_rx(13_568_747)
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
  end
end
