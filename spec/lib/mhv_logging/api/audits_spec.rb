# frozen_string_literal: true

require 'rails_helper'
require 'mhv_logging/client'

describe 'mhv logging client' do
  describe 'audits' do
    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_medications_migrate_to_api_gateway).and_return(false)
      VCR.use_cassette 'mhv_logging_client/session' do
        @client ||= begin
          client = MHVLogging::Client.new(session: { user_id: '12210827' })
          client.authenticate
          client
        end
      end
    end

    let(:client) { @client }

    it 'submits an audit log for signing in', :vcr do
      client_response = client.auditlogin
      expect(client_response.status).to eq(200)
      expect(client_response.body).to eq(status: 'success')
    end

    it 'submits an audit log for signing out', :vcr do
      client_response = client.auditlogout
      expect(client_response.status).to eq(200)
      expect(client_response.body).to eq(status: 'success')
    end
  end
end
