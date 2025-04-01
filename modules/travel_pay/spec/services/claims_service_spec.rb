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
            'claimStatus' => 'ClaimSubmitted',
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
      expected_statuses = ['In progress', 'In progress', 'Incomplete', 'Claim submitted']

      claims = @service.get_claims
      actual_statuses = claims[:data].pluck('claimStatus')

      expect(actual_statuses).to match_array(expected_statuses)
    end

    context 'get claim details' do
      let(:user) { build(:user) }
      let(:claim_details_data) do
        {
          'data' =>
            {
              'claimId' => '73611905-71bf-46ed-b1ec-e790593b8565',
              'claimNumber' => 'TC0000000000001',
              'claimantFirstName' => 'Nolle',
              'claimantMiddleName' => 'Polite',
              'claimantLastName' => 'Barakat',
              'claimStatus' => 'PreApprovedForPayment',
              'appointmentDateTime' => '2024-01-01T16:45:34.465Z',
              'facilityName' => 'Cheyenne VA Medical Center',
              'totalCostRequested' => 20.00,
              'reimbursementAmount' => 14.52,
              'createdOn' => '2025-03-12T20:27:14.088Z',
              'modifiedOn' => '2025-03-12T20:27:14.088Z',
              'appointment' => {
                'id' => '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                'appointmentSource' => 'API',
                'appointmentDateTime' => '2024-01-01T16:45:34.465Z',
                'appointmentType' => 'EnvironmentalHealth',
                'facilityId' => '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                'facilityName' => 'Cheyenne VA Medical Center',
                'serviceConnectedDisability' => 30,
                'appointmentStatus' => 'Complete',
                'externalAppointmentId' => '12345',
                'associatedClaimId' => '73611905-71bf-46ed-b1ec-e790593b8565',
                'associatedClaimNumber' => 'TC0000000000001',
                'isCompleted' => true
              },
              'expenses' => [
                {
                  'id' => '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                  'expenseType' => 'Mileage',
                  'name' => '',
                  'dateIncurred' => '2024-01-01T16:45:34.465Z',
                  'description' => 'mileage-expense',
                  'costRequested' => 10.00,
                  'costSubmitted' => 10.00
                },
                {
                  'id' => '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                  'expenseType' => 'Mileage',
                  'name' => '',
                  'dateIncurred' => '2024-01-01T16:45:34.465Z',
                  'description' => 'mileage-expense',
                  'costRequested' => 10.00,
                  'costSubmitted' => 10.00
                }
              ]
            }
        }
      end
      let(:claim_details_response) do
        Faraday::Response.new(
          body: claim_details_data
        )
      end

      let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

      before do
        allow_any_instance_of(TravelPay::ClaimsClient)
          .to receive(:get_claim_by_id)
          .and_return(claim_details_response)

        auth_manager = object_double(TravelPay::AuthManager.new(123, user), authorize: tokens)
        @service = TravelPay::ClaimsService.new(auth_manager)
      end

      it 'returns expanded claim details when passed a valid id' do
        claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
        actual_claim = @service.get_claim_details(claim_id)

        expect(actual_claim['expenses']).not_to be_empty
        expect(actual_claim['appointment']).not_to be_empty
        expect(actual_claim['totalCostRequested']).to eq(20.00)
        expect(actual_claim['claimStatus']).to eq('Pre approved for payment')
      end

      it 'returns an not found error if a claim with the given id was not found' do
        allow_any_instance_of(TravelPay::ClaimsClient)
          .to receive(:get_claim_by_id)
          .and_raise(Common::Exceptions::ResourceNotFound.new(
                       {
                         'statusCode' => 404,
                         'message' => 'Claim not found.',
                         'success' => false,
                         'data' => nil
                       }
                     ))

        claim_id = SecureRandom.uuid
        expect { @service.get_claim_details(claim_id) }
          .to raise_error(Common::Exceptions::ResourceNotFound, /not found/i)
      end

      it 'throws an ArgumentException if claim_id is invalid format' do
        claim_id = 'this-is-definitely-a-uuid-right'

        expect { @service.get_claim_details(claim_id) }
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
      expect(claims_by_date[:metadata]['success']).to be(true)
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
      expect(claims_by_date[:metadata]['success']).to be(true)
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
      expect(claims_by_date[:metadata]['success']).to be(true)
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
      expect(actual_claim_response).to equal(new_claim_data['data'])
    end

    it 'throws an ArgumentException if btsss_appt_id is invalid format' do
      btsss_appt_id = 'this-is-definitely-a-uuid-right'

      expect { @service.create_new_claim({ 'btsss_appt_id' => btsss_appt_id }) }
        .to raise_error(ArgumentError, /valid UUID/i)

      expect { @service.create_new_claim({ 'btsss_appt_id' => nil }) }
        .to raise_error(ArgumentError, /must provide/i)
    end
  end

  context 'submit claim' do
    let(:user) { build(:user) }
    let(:response) do
      Faraday::Response.new(
        body: { 'data' => { 'claimId' => '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                            'status' => 'InProcess' } }
      )
    end

    let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

    before do
      auth_manager = object_double(TravelPay::AuthManager.new(123, user), authorize: tokens)
      @service = TravelPay::ClaimsService.new(auth_manager)
    end

    it 'returns submitted claim information' do
      expect_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:submit_claim).once
        .and_return(response)

      @service.submit_claim('3fa85f64-5717-4562-b3fc-2c963f66afa6')
    end

    it 'raises an error if claim_id is missing' do
      expect { @service.submit_claim }.to raise_error(ArgumentError)
    end

    it 'raises an error if invalid claim_id provided' do
      # present, wrong format
      expect { @service.submit_claim('claim_numero_uno') }.to raise_error(ArgumentError)

      # empty
      expect { @service.submit_claim('') }.to raise_error(ArgumentError)
    end
  end
end
