# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::Client do
  let(:veis_params_stub) do
    {
      client_id: 'sample_id',
      client_secret: 'sample_client',
      client_info: 1,
      grant_type: 'client_credentials',
      resource: 'sample_resource'
    }
  end

  before do
    @stubs = Faraday::Adapter::Test::Stubs.new
    conn = Faraday.new { |b| b.adapter(:test, @stubs) }
    allow_any_instance_of(TravelPay::Client).to receive(:connection).and_return(conn)
    allow_any_instance_of(TravelPay::Client).to receive(:veis_params).and_return(veis_params_stub)
  end

  context 'request_veis_token' do
    it 'returns veis token from proper endpoint' do
      tenant_id = 'sample_id'
      allow(Settings.travel_pay.veis).to receive(:auth_url).and_return('sample_url')
      allow(Settings.travel_pay.veis).to receive(:tenant_id).and_return(tenant_id)

      @stubs.post("/#{tenant_id}/oauth2/token") do
        [
          200,
          { 'Content-Type': 'application/json' },
          '{"access_token": "fake_veis_token"}'
        ]
      end

      client = TravelPay::Client.new
      response = client.request_veis_token

      expect(JSON.parse(response.body)['access_token']).to eq('fake_veis_token')
      @stubs.verify_stubbed_calls
    end
  end

  context 'ping' do
    it 'receives response from ping endpoint' do
      allow(Settings.travel_pay.veis).to receive(:auth_url).and_return('sample_url')
      allow(Settings.travel_pay.veis).to receive(:tenant_id).and_return('sample_id')
      @stubs.get('/api/v1/Sample/ping') do
        [
          200,
          { 'Content-Type': 'application/json' }
        ]
      end
      client = TravelPay::Client.new
      response = client.ping('sample_token')

      expect(response).to be_success
      @stubs.verify_stubbed_calls
    end
  end
end
