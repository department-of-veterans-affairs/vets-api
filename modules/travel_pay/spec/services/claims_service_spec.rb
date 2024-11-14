# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

describe TravelPay::ClaimsService do
  context 'get_claims' do
    let(:user) { build(:user) }
    let(:claims_data) do
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
          },
          {
            'id' => '73611905-71bf-46ed-b1ec-e790593b8565',
            'claimNumber' => 'TC0004',
            'claimName' => '9d81c1a1-cd05-47c6-be97-d14dec579893',
            'claimStatus' => 'Claim Submitted',
            'appointmentDateTime' => nil,
            'facilityName' => 'Tomah VA Medical Center',
            'createdOn' => '2023-12-29T22:00:57.915Z',
            'modifiedOn' => '2024-01-03T22:00:57.915Z'
          }
        ]
      }
    end
    let(:claims_response) do
      Faraday::Response.new(
        body: claims_data
      )
    end

    let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

    before do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims)
        .and_return(claims_response)

      auth_manager = object_double(TravelPay::AuthManager.new(123, user), authorize: tokens)
      @service = TravelPay::ClaimsService.new(auth_manager)
    end

    it 'returns sorted and parsed claims' do
      expected_statuses = ['In Progress', 'In Progress', 'Incomplete', 'Claim Submitted']

      claims = @service.get_claims
      actual_statuses = claims[:data].pluck('claimStatus')

      expect(actual_statuses).to match_array(expected_statuses)
    end

    context 'get claim by id' do
      it 'returns a single claim when passed a valid id' do
        claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
        expected_claim = claims_data['data'].find { |c| c['id'] == claim_id }
        actual_claim = @service.get_claim_by_id(claim_id)

        expect(actual_claim).to eq(expected_claim)
      end

      it 'returns nil if a claim with the given id was not found' do
        claim_id = SecureRandom.uuid
        actual_claim = @service.get_claim_by_id(claim_id)

        expect(actual_claim).to eq(nil)
      end

      it 'throws an ArgumentException if claim_id is invalid format' do
        claim_id = 'this-is-definitely-a-uuid-right'

        expect { @service.get_claim_by_id(claim_id) }
          .to raise_error(ArgumentError, /valid UUID/i)
      end
    end

    context 'filter by appt date' do
      it 'returns claims that match appt date if specified' do
        claims = @service.get_claims({ 'appt_datetime' => '2024-01-01' })

        expect(claims.count).to equal(1)
      end

      it 'returns 0 claims if appt date does not match' do
        claims = @service.get_claims({ 'appt_datetime' => '1700-01-01' })

        expect(claims[:data].count).to equal(0)
      end

      it 'returns all claims if appt date is invalid' do
        claims = @service.get_claims({ 'appt_datetime' => 'banana' })

        expect(claims[:data].count).to equal(claims_data['data'].count)
      end

      it 'returns all claims if appt date is not specified' do
        claims_empty_date = @service.get_claims({ 'appt_datetime' => '' })
        claims_nil_date = @service.get_claims({ 'appt_datetime' => 'banana' })
        claims_no_param = @service.get_claims

        expect(claims_empty_date[:data].count).to equal(claims_data['data'].count)
        expect(claims_nil_date[:data].count).to equal(claims_data['data'].count)
        expect(claims_no_param[:data].count).to equal(claims_data['data'].count)
      end
    end
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
        response_body: claims_by_date_data,
        status: 200
      )
    end

    let(:single_claim_by_date_response) do
      Faraday::Response.new(
        response_body: {
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
        },
        status: 200
      )
    end

    let(:claims_no_data_response) do
      Faraday::Response.new(
        response_body: {
          'statusCode' => 200,
          'message' => 'No claims found.',
          'success' => true,
          'data' => []
        },
        status: 200
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

      claims_by_date = @service.get_claims_by_date_range({ 'start_date' => '2024-01-01T16:45:34Z',
                                                           'end_date' => '2024-03-01T16:45:34Z' })

      expect(claims_by_date.status).to equal(200)
      expect(claims_by_date.body['data'].count).to equal(3)
      expect(claims_by_date.body['statusCode']).to equal(200)
      expect(claims_by_date.body['success']).to eq(true)
      expect(claims_by_date.body['message']).to eq('Data retrieved successfully.')
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

      expect(claims_by_date.body['data'].count).to equal(1)
      expect(claims_by_date.body['statusCode']).to equal(200)
      expect(claims_by_date.body['success']).to eq(true)
      expect(claims_by_date.body['message']).to eq('Data retrieved successfully.')
    end

    it 'returns 400 with message if both start and end dates are not provided' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token], {
                'start_date' => '2024-01-01T16:45:34Z'
              })
        .and_raise(ArgumentError.new(message: 'Both start and end dates are required.'))

      bad_claims_call = @service.get_claims_by_date_range({ 'start_date' => '2024-01-01T16:45:34Z' })

      expect(bad_claims_call.status).to equal(400)
      expect(bad_claims_call.body['statusCode']).to equal(400)
      expect(bad_claims_call.body['success']).to eq(false)
      expect(bad_claims_call.body['message']).to include(/Both start and end/i)
    end

    it 'handles random, unknown errors' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .and_raise(NameError.new('Uninitialized constant.', 'new_constant'))

      bad_claims_call = @service.get_claims_by_date_range(
        { 'start_date' => '2024-01-01T16:45:34Z', 'end_date' => '2024-01-01T16:45:34Z' }
      )
      expect(bad_claims_call.status).to equal(520)
      expect(bad_claims_call.body['statusCode']).to equal(520)
      expect(bad_claims_call.body['success']).to eq(false)
      expect(bad_claims_call.body['message']).to include(/Uninitialized constant/i)
    end

    it 'returns 400 with error message if dates are invalid' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token], {
                'start_date' => '2024-01-01T16:45:34Z',
                'end_date' => 'banana'
              })
        .and_raise(ArgumentError.new(message: 'invalid date.'))

      bad_claims_call = @service.get_claims_by_date_range(
        { 'start_date' => '2024-01-01T16:45:34Z', 'end_date' => 'banana' }
      )
      expect(bad_claims_call.status).to equal(400)
      expect(bad_claims_call.body['statusCode']).to equal(400)
      expect(bad_claims_call.body['success']).to eq(false)
      expect(bad_claims_call.body['message']).to include(/invalid date/i)
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

      expect(claims_by_date.body['data'].count).to equal(0)
      expect(claims_by_date.body['statusCode']).to equal(200)
      expect(claims_by_date.body['success']).to eq(true)
      expect(claims_by_date.body['message']).to eq('No claims found.')
    end

    it 'returns original error' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token], {
                'start_date' => '2024-01-01T16:45:34Z',
                'end_date' => '2024-03-01T16:45:34Z'
              })
        .and_raise(Common::Exceptions::BackendServiceException.new(
                     'VA900',
                     { source: 'test' },
                     401,
                     {
                       'statusCode' => 401,
                       'message' => 'A contact with the specified ICN was not found.',
                       'success' => false,
                       'data' => nil
                     }
                   ))

      claims_by_date = @service.get_claims_by_date_range({
                                                           'start_date' => '2024-01-01T16:45:34Z',
                                                           'end_date' => '2024-03-01T16:45:34Z'
                                                         })

      expect(claims_by_date.body['statusCode']).to equal(401)
      expect(claims_by_date.body['success']).to eq(false)
      expect(claims_by_date.body['message']).to eq('A contact with the specified ICN was not found.')
    end
  end

  context 'create_new_claim' do
    let(:user) { build(:user) }
    let(:new_claim_data) do
      {
        'data' =>
          {
            'claimId' => '3fa85f64-5717-4562-b3fc-2c963f66afa6'
          }
      }
    end
    let(:new_claim_response) do
      Faraday::Response.new(
        body: new_claim_data
      )
    end

    let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

    before do
      auth_manager = object_double(TravelPay::AuthManager.new(123, user), authorize: tokens)
      @service = TravelPay::ClaimsService.new(auth_manager)
    end

    it 'returns a claim ID when passed a valid btsss appt id' do
      btsss_appt_id = '73611905-71bf-46ed-b1ec-e790593b8565'
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:create_claim)
        .with(tokens[:veis_token], tokens[:btsss_token], { 'btsss_appt_id' => btsss_appt_id,
                                                           'claim_name' => 'SMOC claim' })
        .and_return(new_claim_response)

      actual_claim_response = @service.create_new_claim({
                                                          'btsss_appt_id' => btsss_appt_id,
                                                          'claim_name' => 'SMOC claim'
                                                        })

      expect(actual_claim_response['data']).to equal(new_claim_data['data'])
    end

    it 'throws an ArgumentException if btsss_appt_id is invalid format' do
      btsss_appt_id = 'this-is-definitely-a-uuid-right'

      expect { @service.create_new_claim({ 'btsss_appt_id' => btsss_appt_id }) }
        .to raise_error(ArgumentError, /valid UUID/i)

      expect { @service.create_new_claim({ 'btsss_appt_id' => nil }) }
        .to raise_error(ArgumentError, /must provide/i)
    end
  end
end
