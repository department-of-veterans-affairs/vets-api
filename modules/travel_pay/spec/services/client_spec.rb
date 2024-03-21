# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::Client do
  before do
    @stubs = Faraday::Adapter::Test::Stubs.new
    conn = Faraday.new { |b| b.adapter(:test, @stubs) }
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
      tenant_id = Settings.travel_pay.veis.tenant_id

      @stubs.get('/api/v1/claims') do
        [
          200,
          {},
          {'data' => [
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
          ]}
        ]
      end

      expected_ordered_ids = ['uuid2', 'uuid3', 'uuid1']

      client = TravelPay::Client.new
      claims = client.get_claims('veis_token', 'btsss_token')
      actual_claim_ids = claims.map { |c| c[:id] }

      expect(actual_claim_ids).to eq(expected_ordered_ids)
      @stubs.verify_stubbed_calls
    end
  end
end
