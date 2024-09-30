# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::ClaimsClient do
  let(:user) { build(:user) }

  before do
    @stubs = Faraday::Adapter::Test::Stubs.new

    conn = Faraday.new do |c|
      c.adapter(:test, @stubs)
      c.response :json
      c.request :json
    end

    allow_any_instance_of(TravelPay::ClaimsClient).to receive(:connection).and_return(conn)
  end

  context 'prod settings' do
    it 'returns both subscription keys in headers' do
      headers =
        {
          'Content-Type' => 'application/json',
          'Ocp-Apim-Subscription-Key-E' => 'e_key',
          'Ocp-Apim-Subscription-Key-S' => 's_key'
        }

      with_settings(Settings, vsp_environment: 'production') do
        with_settings(Settings.travel_pay,
                      { subscription_key_e: 'e_key', subscription_key_s: 's_key' }) do
          expect(subject.send(:claim_headers)).to eq(headers)
        end
      end
    end
  end

  context '/claims' do
    before do
      allow_any_instance_of(TravelPay::TokenService)
        .to receive(:get_tokens)
        .and_return('veis_token', 'btsss_token')
    end

    # GET
    it 'returns response from claims endpoint' do
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

      expected_ids = %w[uuid1 uuid2 uuid3]

      client = TravelPay::ClaimsClient.new
      claims_response = client.get_claims('veis_token', 'btsss_token')
      actual_claim_ids = claims_response.body['data'].pluck('id')

      expect(actual_claim_ids).to eq(expected_ids)
    end

    # POST create_claim
    it 'returns a claim ID from the claims endpoint' do
      claim_id = '3fa85f64-5717-4562-b3fc-2c963f66afa6'
      body = { 'appointmentId' => 'fake_btsss_appt_id', 'claimName' => '', 'claimantType' => 'Veteran' }.to_json
      @stubs.post('/api/v1.1/claims', body) do
        [
          200,
          {},
          {
            'data' =>
              {
                'claimId' => claim_id
              }
          }
        ]
      end

      client = TravelPay::ClaimsClient.new
      new_claim_response = client.create_claim('veis_token', 'btsss_token', { 'btsss_appt_id' => 'fake_btsss_appt_id' })
      actual_claim_id = new_claim_response.body['data']['claimId']

      expect(actual_claim_id).to eq(claim_id)
    end
  end
end
