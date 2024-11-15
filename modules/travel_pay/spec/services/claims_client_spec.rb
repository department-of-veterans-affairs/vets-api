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

    it 'returns response from claims/search endpoint' do
      @stubs.get('api/v1.1/claims/search-by-appointment-date') do
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

      expected = %w[uuid1 uuid3]

      client = TravelPay::ClaimsClient.new
      claims_response = client.get_claims_by_date('veis_token', 'btsss_token',
                                                  { 'start_date' => '2024-01-01T16:45:34.465Z',
                                                    'end_date' => '2024-02-01T16:45:34.465Z' })
      actual_ids = claims_response.body['data'].pluck('id')

      expect(actual_ids).to eq(expected)
    end

    context 'get_claims_by_date_range' do
      let(:user) { build(:user) }
      let(:claims_by_date_data) do
        {
          'statusCode' => 200,
          'message' => 'Data retrieved successfully.',
          'success' => true,
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
      end
      let(:claims_by_date_response) do
        Faraday::Response.new(
          body: claims_by_date_data
        )
      end

      let(:single_claim_by_date_response) do
        Faraday::Response.new(
          body: {
            'statusCode' => 200,
            'message' => 'Data retrieved successfully.',
            'success' => true,
            'data' => [
              {
                'id' => 'uuid1',
                'claimNumber' => 'TC0000000000001',
                'claimStatus' => 'InProgress',
                'appointmentDateTime' => '2024-01-01T16:45:34.465Z',
                'facilityName' => 'Cheyenne VA Medical Center',
                'createdOn' => '2024-03-22T21:22:34.465Z',
                'modifiedOn' => '2024-01-01T16:44:34.465Z'
              }
            ]
          }
        )
      end

      let(:claims_no_data_response) do
        Faraday::Response.new(
          body: {
            'statusCode' => 200,
            'message' => 'No claims found.',
            'success' => true,
            'data' => []
          }
        )
      end

      let(:claims_error_response) do
        Faraday::Response.new(
          body: {
            error: 'Generic error.'
          }
        )
      end

      let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

      before do
        auth_manager = object_double(TravelPay::AuthManager.new(123, user), authorize: tokens)
        @service = TravelPay::ClaimsService.new(auth_manager)
      end

      it 'returns claims that are in the specified date range' do
        allow_any_instance_of(TravelPay::ClaimsClient)
          .to receive(:get_claims_by_date)
          .with(tokens[:veis_token], tokens[:btsss_token], {
                  'start_date' => '2024-01-01T16:45:34Z',
                  'end_date' => '2024-03-01T16:45:34Z'
                })
          .and_return(claims_by_date_response)

        claims_by_date = @service.get_claims_by_date_range({
                                                             'start_date' => '2024-01-01T16:45:34Z',
                                                             'end_date' => '2024-03-01T16:45:34Z'
                                                           })

        expect(claims_by_date[:data].count).to equal(3)
        expect(claims_by_date[:metadata]['status']).to equal(200)
        expect(claims_by_date[:metadata]['success']).to eq(true)
        expect(claims_by_date[:metadata]['message']).to eq('Data retrieved successfully.')
      end

      it 'returns a single claim if dates are the same' do
        allow_any_instance_of(TravelPay::ClaimsClient)
          .to receive(:get_claims_by_date)
          .with(tokens[:veis_token], tokens[:btsss_token], {
                  'start_date' => '2024-01-01T16:45:34Z',
                  'end_date' => '2024-01-01T16:45:34Z'
                })
          .and_return(single_claim_by_date_response)

        claims_by_date = @service.get_claims_by_date_range({
                                                             'start_date' => '2024-01-01T16:45:34Z',
                                                             'end_date' => '2024-01-01T16:45:34Z'
                                                           })

        expect(claims_by_date[:data].count).to equal(1)
        expect(claims_by_date[:metadata]['status']).to equal(200)
        expect(claims_by_date[:metadata]['success']).to eq(true)
        expect(claims_by_date[:metadata]['message']).to eq('Data retrieved successfully.')
      end

      it 'throws an Argument exception if both start and end dates are not provided' do
        expect { @service.get_claims_by_date_range({ 'start_date' => '2024-01-01T16:45:34.465Z' }) }
          .to raise_error(ArgumentError, /Both start and end/i)
      end

      it 'throws an exception if dates are invalid' do
        expect do
          @service.get_claims_by_date_range(
            { 'start_date' => '2024-01-01T16:45:34.465Z', 'end_date' => 'banana' }
          )
        end
          .to raise_error(ArgumentError, /Invalid date/i)
      end

      it 'returns success but empty array if no claims found' do
        allow_any_instance_of(TravelPay::ClaimsClient)
          .to receive(:get_claims_by_date)
          .with(tokens[:veis_token], tokens[:btsss_token], {
                  'start_date' => '2024-01-01T16:45:34Z',
                  'end_date' => '2024-03-01T16:45:34Z'
                })
          .and_return(claims_no_data_response)

        claims_by_date = @service.get_claims_by_date_range({
                                                             'start_date' => '2024-01-01T16:45:34Z',
                                                             'end_date' => '2024-03-01T16:45:34Z'
                                                           })

        expect(claims_by_date[:data].count).to equal(0)
        expect(claims_by_date[:metadata]['status']).to equal(200)
        expect(claims_by_date[:metadata]['success']).to eq(true)
        expect(claims_by_date[:metadata]['message']).to eq('No claims found.')
      end

      it 'returns nil if error' do
        allow_any_instance_of(TravelPay::ClaimsClient)
          .to receive(:get_claims_by_date)
          .with(tokens[:veis_token], tokens[:btsss_token], {
                  'start_date' => '2024-01-01T16:45:34Z',
                  'end_date' => '2024-03-01T16:45:34Z'
                })
          .and_return(claims_error_response)

        claims_by_date = @service.get_claims_by_date_range({
                                                             'start_date' => '2024-01-01T16:45:34Z',
                                                             'end_date' => '2024-03-01T16:45:34Z'
                                                           })
        expect(claims_by_date).to be_nil
      end
    end

    # POST create_claim
    it 'returns a claim ID from the claims endpoint' do
      claim_id = '3fa85f64-5717-4562-b3fc-2c963f66afa6'
      body = { 'appointmentId' => 'fake_btsss_appt_id', 'claimName' => 'SMOC claim',
               'claimantType' => 'Veteran' }.to_json
      @stubs.post('api/v1.1/claims') do
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
      new_claim_response = client.create_claim('veis_token', 'btsss_token', body)
      actual_claim_id = new_claim_response.body['data']['claimId']

      expect(actual_claim_id).to eq(claim_id)
    end
  end
end
