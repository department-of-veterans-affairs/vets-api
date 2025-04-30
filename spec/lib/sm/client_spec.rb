# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'
require 'sm/configuration'

describe SM::Client do
  before do
    VCR.use_cassette('sm_client/session') do
      @client ||= begin
        client = SM::Client.new(session: { user_id: '10616687' })
        client.authenticate
        client
      end
    end
  end

  let(:client) { @client }

  describe 'Test new API gateway methods' do
    let(:config) { SM::Configuration.instance }

    context 'when mhv_secure_messaging_migrate_to_api_gateway flipper flag is true' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_migrate_to_api_gateway).and_return(true)
        allow(Settings.mhv.sm).to receive(:x_api_key).and_return('test-api-key')
      end
      it 'returns the x-api-key header' do
        result = client.send(:auth_headers)
        headers = { 'base-header' => 'value', 'appToken' => 'test-app-token', 'mhvCorrelationId' => '10616687' }
        allow(client).to receive(:auth_headers).and_return(headers)
        expect(result).to include('x-api-key' => 'test-api-key')
        expect(config.x_api_key).to eq('test-api-key')
      end
    end
      
    context 'when mhv_secure_messaging_migrate_to_api_gateway flipper flag is false' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_migrate_to_api_gateway).and_return(false)
      end
      it 'returns nil for x-api-key' do
        result = client.send(:auth_headers)
        headers = { 'base-header' => 'value', 'appToken' => 'test-app-token', 'mhvCorrelationId' => '10616687' }
        allow(client).to receive(:auth_headers).and_return(headers)
        expect(result).not_to include('x-api-key')
      end
    end
  end
end
