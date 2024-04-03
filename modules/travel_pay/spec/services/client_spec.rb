# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::Client do
  before do
    @stubs = Faraday::Adapter::Test::Stubs.new

    conn = Faraday.new do |c|
      c.adapter(:test, @stubs)
      c.response :json
      c.request :json
    end

    allow_any_instance_of(TravelPay::Client).to receive(:connection).and_return(conn)
  end

  context 'request_veis_token' do
    it 'returns veis token from proper endpoint' do
      tenant_id = Settings.travel_pay.veis.tenant_id

      @stubs.post("#{tenant_id}/oauth2/token") do
        [
          200,
          { 'Content-Type': 'application/json' },
          '{"access_token": "fake_veis_token"}'
        ]
      end

      client = TravelPay::Client.new
      token = client.request_veis_token

      expect(token).to eq('fake_veis_token')
      @stubs.verify_stubbed_calls
    end
  end

  context 'request_btsss_token' do
    let(:vagov_token) { 'fake_vagov_token' }
    let(:json_request_body) { { authJwt: 'fake_vagov_token' }.to_json }

    it 'returns btsss token from proper endpoint' do
      @stubs.post('/api/v1/Auth/access-token', json_request_body) do
        [
          200,
          { 'Content-Type': 'application/json' },
          '{"access_token": "fake_btsss_token"}'
        ]
      end

      client = TravelPay::Client.new
      token = client.request_btsss_token('fake_veis_token', vagov_token)

      expect(token).to eq('fake_btsss_token')
      @stubs.verify_stubbed_calls
    end
  end

  context 'ping' do
    it 'receives response from ping endpoint' do
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

  context '/claims' do
    it 'returns a list of claims sorted by most recently updated' do
      @stubs.get('/api/v1/claims') do
        [
          200,
          {},
          {
            'data' => [
              {
                'id' => 'uuid1',
                'modified_on' => '2024-01-01'
              },
              {
                'id' => 'uuid2',
                'modified_on' => '2024-03-01'
              },
              {
                'id' => 'uuid3',
                'modified_on' => '2024-02-01'
              }
            ]
          }
        ]
      end

      expected_ordered_ids = %w[uuid2 uuid3 uuid1]

      client = TravelPay::Client.new
      claims = client.get_claims('veis_token', 'btsss_token')
      actual_claim_ids = claims.pluck(:id)

      expect(actual_claim_ids).to eq(expected_ordered_ids)
    end
  end

  context 'authorized_ping' do
    it 'receives response from authorized-ping endpoint' do
      allow(Settings.travel_pay.veis).to receive(:auth_url).and_return('sample_url')
      allow(Settings.travel_pay.veis).to receive(:tenant_id).and_return('sample_id')
      @stubs.get('/api/v1/Sample/authorized-ping') do
        [
          200,
          { 'Content-Type': 'application/json' }
        ]
      end
      client = TravelPay::Client.new
      response = client.authorized_ping('veis_token', 'btsss_token')

      expect(response).to be_success
      @stubs.verify_stubbed_calls
    end
  end
end
