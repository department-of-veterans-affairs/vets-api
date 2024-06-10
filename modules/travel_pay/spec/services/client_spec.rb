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
          '{"data": {"accessToken": "fake_btsss_token"}}'
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
      payload = { ContactID: 'test' }
      fake_btsss_token = JWT.encode(payload, nil, 'none')

      @stubs.get('/api/v1/claims') do
        [
          200,
          {},
          {
            'data' => [
              {
                'id' => 'uuid1',
                'claimNumber' => 'TC0000000000001',
                'claimStatus' => 'InProgress',
                'appointmentDateTime' => '2024-01-01T16:45:34.465Z',
                'facilityName' => 'Cheyenne VA Medical Center',
                'createdOn' => '2024-03-22T21:22:34.465Z',
                'modifiedOn' => '2024-01-01T16:44:34.465Z'
              },
              {
                'id' => 'uuid2',
                'claimNumber' => 'TC0000000000002',
                'claimStatus' => 'InProgress',
                'appointmentDateTime' => '2024-03-01T16:45:34.465Z',
                'facilityName' => 'Cheyenne VA Medical Center',
                'createdOn' => '2024-02-22T21:22:34.465Z',
                'modifiedOn' => '2024-03-01T00:00:00.0Z'
              },
              {
                'id' => 'uuid3',
                'claimNumber' => 'TC0000000000002',
                'claimStatus' => 'Incomplete',
                'appointmentDateTime' => '2024-02-01T16:45:34.465Z',
                'facilityName' => 'Cheyenne VA Medical Center',
                'createdOn' => '2024-01-22T21:22:34.465Z',
                'modifiedOn' => '2024-02-01T00:00:00.0Z'
              }
            ]
          }
        ]
      end

      expected_ordered_ids = %w[uuid2 uuid3 uuid1]
      expected_statuses = ['In Progress', 'Incomplete', 'In Progress']

      client = TravelPay::Client.new
      claims = client.get_claims('veis_token', fake_btsss_token)
      actual_claim_ids = claims[:data].pluck(:id)
      actual_statuses = claims[:data].pluck(:claimStatus)

      expect(actual_claim_ids).to eq(expected_ordered_ids)
      expect(actual_statuses).to eq(expected_statuses)
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
