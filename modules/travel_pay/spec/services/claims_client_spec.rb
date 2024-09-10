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

  # context 'request_veis_token' do
  #   it 'returns veis token from proper endpoint' do
  #     tenant_id = Settings.travel_pay.veis.tenant_id
  #     @stubs.post("#{tenant_id}/oauth2/token") do
  #       [
  #         200,
  #         { 'Content-Type': 'application/json' },
  #         '{"access_token": "fake_veis_token"}'
  #       ]
  #     end
  #     client = TravelPay::Client.new
  #     token = client.request_veis_token

  #     expect(token).to eq('fake_veis_token')
  #     @stubs.verify_stubbed_calls
  #   end
  # end

  # context 'request_btsss_token' do
  #   let(:vagov_token) { 'fake_vagov_token' }
  #   let(:json_request_body) { { authJwt: 'fake_vagov_token' }.to_json }

  #   it 'returns btsss token from proper endpoint' do
  #     @stubs.post('/api/v1/Auth/access-token', json_request_body) do
  #       [
  #         200,
  #         { 'Content-Type': 'application/json' },
  #         '{"data": {"accessToken": "fake_btsss_token"}}'
  #       ]
  #     end

  #     client = TravelPay::Client.new
  #     token = client.request_btsss_token('fake_veis_token', vagov_token)

  #     expect(token).to eq('fake_btsss_token')
  #     @stubs.verify_stubbed_calls
  #   end
  # end

  context '/claims' do
    before do
      allow_any_instance_of(TravelPay::TokenService)
        .to receive(:get_tokens)
        .and_return({ 'veis_token' => 'veis_token', 'btsss_token' => 'btsss_token' })
      #   # allow_any_instance_of(TravelPay::TokenService)
      #   #   .to receive(:request_sts_token)
      #   #   .and_return('sts_token')
      #   # allow_any_instance_of(TravelPay::TokenService)
      #   #   .to receive(:request_btsss_token)
      #   #   .with(user)
      #   #   .and_return('btsss_token')
    end

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
  end
end
