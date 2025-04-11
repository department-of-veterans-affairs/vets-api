# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe SM::Client do
  before(:all) do
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
    before do
      allow(Settings.mhv.sm).to receive(:use_new_api).and_return(true)
      allow(Settings.mhv.sm).to receive_messages(use_new_api: true, app_token: 'test-app-token')
      allow(Settings.mhv.sm).to receive_messages(x_api_key: 'test-api-key')
      allow(Settings.mhv_mobile.sm).to receive(:app_token).and_return('mobile-test-app-token')
      allow(Settings.mhv_mobile).to receive_messages(x_api_key: 'mobile-test-api-key')
      allow(client).to receive(:config).and_return(OpenStruct.new(base_request_headers: { 'base-header' => 'value' },
                                                                  app_token: 'test-app-token'))
    end

    describe '#auth_headers' do
      let(:use_new_api) { true }

      it 'returns headers with appToken, mhvCorrelationId, and x-api-key' do
        result = client.send(:auth_headers)
        headers = { 'base-header' => 'value', 'appToken' => 'test-app-token', 'mhvCorrelationId' => '10616687' }
        allow(client).to receive(:get_headers).with(headers).and_return(headers)
        allow(client).to receive(:get_headers).and_return(client.send(:get_headers, headers))
        expect(result).to include('x-api-key' => 'test-api-key')
      end
    end

    describe '#get_headers' do
      let(:headers) { { 'custom-header' => 'value', 'appToken' => app_token } }

      context 'when use_new_api is true' do
        let(:use_new_api) { true }
        let(:app_token) { 'test-app-token' }

        it 'adds x-api-key to headers' do
          result = client.send(:get_headers, headers)
          expect(result).to include('custom-header' => 'value', 'x-api-key' => 'test-api-key')
        end
      end

      context 'when use_new_api is false' do
        let(:use_new_api) { false }
        let(:app_token) { 'test-app-token' }

        before do
          allow(Settings.mhv.sm).to receive(:use_new_api).and_return(use_new_api)
          allow(Settings.mhv.sm).to receive_messages(x_api_key: nil)
        end

        it 'returns headers without x-api-key' do
          result = client.send(:get_headers, headers)
          expect(result).to eq(headers)
          expect(result).not_to include('x-api-key')
        end
      end
    end
  end
end
