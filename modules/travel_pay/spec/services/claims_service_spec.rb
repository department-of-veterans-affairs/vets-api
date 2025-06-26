# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

describe TravelPay::ClaimsService do
  context 'get_claims' do
    let(:user) { build(:user) }
    let(:claims_data) do
      {
        'statusCode' => 200,
        'message' => 'Data retrieved successfully.',
        'success' => true,
        'pageNumber' => 1,
        'pageSize' => 50,
        'totalRecordCount' => 4,
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
      @service = TravelPay::ClaimsService.new(auth_manager, user)
    end

    it 'returns sorted and parsed claims' do
      expected_statuses = ['In progress', 'In progress', 'Incomplete', 'Claim submitted']

      claims = @service.get_claims({})
      actual_statuses = claims[:data].pluck('claimStatus')

      expect(actual_statuses).to match_array(expected_statuses)
    end

    it 'passes default params' do
      expected_statuses = ['In progress', 'In progress', 'Incomplete', 'Claim submitted']
      expect_any_instance_of(TravelPay::ClaimsClient).to receive(:get_claims).with(tokens[:veis_token],
                                                                                   tokens[:btsss_token],
                                                                                   { page_size: 50, page_number: 1 })
      claims = @service.get_claims({})
      actual_statuses = claims[:data].pluck('claimStatus')

      expect(actual_statuses).to match_array(expected_statuses)
    end

    it 'passes params that were given' do
      expected_statuses = ['In progress', 'In progress', 'Incomplete', 'Claim submitted']
      expect_any_instance_of(TravelPay::ClaimsClient).to receive(:get_claims).with(tokens[:veis_token],
                                                                                   tokens[:btsss_token],
                                                                                   { page_size: 10, page_number: 2 })
      claims = @service.get_claims({ 'page_size' => 10, 'page_number' => 2 })
      actual_statuses = claims[:data].pluck('claimStatus')

      expect(actual_statuses).to match_array(expected_statuses)
    end
  end

  context 'get claim details' do
    let(:user) { build(:user) }
    let(:claim_details_data) do
      {
        'data' =>
          {
            'claimId' => '73611905-71bf-46ed-b1ec-e790593b8565',
            'claimNumber' => 'TC0000000000001',
            'claimName' => 'Claim created for NOLLE BARAKAT',
            'claimantFirstName' => 'Nolle',
            'claimantMiddleName' => 'Polite',
            'claimantLastName' => 'Barakat',
            'claimStatus' => 'PreApprovedForPayment',
            'appointmentDate' => '2024-01-01T16:45:34.465Z',
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

    let(:document_ids_data) do
      {
        'data' => [
          {
            'documentId' => 'uuid1',
            'filename' => 'DecisionLetter.pdf',
            'mimetype' => 'application/pdf',
            'createdon' => '2025-03-24T14:00:52.893Z'
          },
          {
            'documentId' => 'uuid2',
            'filename' => 'screenshot.jpg',
            'mimetype' => 'image/jpeg',
            'createdon' => '2025-03-24T14:00:52.893Z'
          }
        ]
      }
    end

    let(:document_ids_response) do
      Faraday::Response.new(
        body: document_ids_data
      )
    end

    let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

    before do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claim_by_id)
        .and_return(claim_details_response)

      allow_any_instance_of(TravelPay::DocumentsClient)
        .to receive(:get_document_ids)
        .and_return(document_ids_response)

      auth_manager = object_double(TravelPay::AuthManager.new(123, user), authorize: tokens)
      @service = TravelPay::ClaimsService.new(auth_manager, user)
    end

    it 'returns expanded claim details when passed a valid id' do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_claims_management, instance_of(User)).and_return(false)
      claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
      actual_claim = @service.get_claim_details(claim_id)

      expect(actual_claim['expenses']).not_to be_empty
      expect(actual_claim['appointment']).not_to be_empty
      expect(actual_claim['totalCostRequested']).to eq(20.00)
      expect(actual_claim['documents']).to be_empty
      expect(actual_claim['claimStatus']).to eq('Pre approved for payment')
    end

    it 'includes an empty document array if document call fails' do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_claims_management, instance_of(User)).and_return(true)

      allow_any_instance_of(TravelPay::DocumentsClient)
        .to receive(:get_document_ids)
        .and_raise(Common::Exceptions::ResourceNotFound.new(
                     {
                       'statusCode' => 404,
                       'message' => 'Claim not found.',
                       'success' => false,
                       'data' => nil
                     }
                   ))

      claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
      actual_claim = @service.get_claim_details(claim_id)

      expect(actual_claim['documents']).to be_empty
      expect(actual_claim['expenses']).not_to be_empty
      expect(actual_claim['appointment']).not_to be_empty
      expect(actual_claim['totalCostRequested']).to eq(20.00)
      expect(actual_claim['claimStatus']).to eq('Pre approved for payment')
    end

    it 'includes document summary info when include_documents flag is true' do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_claims_management, instance_of(User)).and_return(true)
      claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
      actual_claim = @service.get_claim_details(claim_id)

      expected_doc_ids = %w[uuid1 uuid2]
      actual_doc_ids = actual_claim['documents'].pluck('documentId')

      expect(actual_claim['documents']).not_to be_empty
      expect(actual_doc_ids).to eq(expected_doc_ids)
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

  context 'get_claims_by_date_range' do
    let(:user) { build(:user) }
    let(:claims_by_date_meta) do
      {
        'statusCode' => 200,
        'message' => 'Data retrieved successfully.',
        'success' => true,
        'totalRecordCount' => 3
      }
    end

    let(:claims_by_date_data) do
      [
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
    end
    let(:claims_by_date_response1) do
      Faraday::Response.new(
        body: {
          **claims_by_date_meta,
          'data' => [claims_by_date_data[0]]
        }
      )
    end
    let(:claims_by_date_response2) do
      Faraday::Response.new(
        body: {
          **claims_by_date_meta,
          'data' => [claims_by_date_data[1]]
        }
      )
    end
    let(:claims_by_date_response3) do
      Faraday::Response.new(
        body: {
          **claims_by_date_meta,
          'data' => [claims_by_date_data[2]]
        }
      )
    end

    let(:single_claim_by_date_response) do
      Faraday::Response.new(
        body: {
          'statusCode' => 200,
          'message' => 'Data retrieved successfully.',
          'success' => true,
          'totalRecordCount' => 1,
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
          'totalRecordCount' => 0,
          'data' => []
        }
      )
    end

    let(:claims_error_response) do
      Faraday::Response.new(
        response_body: {
          'statusCode' => 500,
          'message' => 'An error occurred while processing your request.',
          'success' => false,
          'error' => 'Generic error.'
        },
        status: 500
      )
    end

    let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

    before do
      auth_manager = object_double(TravelPay::AuthManager.new(123, user), authorize: tokens)
      @service = TravelPay::ClaimsService.new(auth_manager, user)
    end

    it 'paginates and returns claims that are in the specified date range' do
      expected_ids = %w[uuid1 uuid2 uuid3]
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token], {
                start_date: '2024-01-01T16:45:34Z',
                end_date: '2024-03-01T16:45:34Z',
                page_size: 1,
                page_number: 1
              })
        .and_return(claims_by_date_response1)
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token], {
                start_date: '2024-01-01T16:45:34Z',
                end_date: '2024-03-01T16:45:34Z',
                page_size: 1,
                page_number: 2
              })
        .and_return(claims_by_date_response2)
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token], {
                start_date: '2024-01-01T16:45:34Z',
                end_date: '2024-03-01T16:45:34Z',
                page_size: 1,
                page_number: 3
              })
        .and_return(claims_by_date_response3)

      claims_by_date = @service.get_claims_by_date_range({
                                                           'start_date' => '2024-01-01T16:45:34Z',
                                                           'end_date' => '2024-03-01T16:45:34Z',
                                                           'page_size' => 1
                                                         })

      expect(claims_by_date[:data].pluck('id')).to match_array(expected_ids)
      expect(claims_by_date[:data].count).to equal(claims_by_date[:metadata]['totalRecordCount'])
      expect(claims_by_date[:metadata]['totalRecordCount']).to equal(3)
    end

    it 'returns a single claim if dates are the same' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .and_return(single_claim_by_date_response)

      claims_by_date = @service.get_claims_by_date_range({
                                                           'start_date' => '2024-01-01T16:45:34Z',
                                                           'end_date' => '2024-01-01T16:45:34Z'
                                                         })

      expect(claims_by_date[:data].count).to equal(claims_by_date[:metadata]['totalRecordCount'])
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
        .to raise_error(ArgumentError, /no time information/i)
    end

    it 'returns success but empty array if no claims found' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .and_return(claims_no_data_response)

      claims_by_date = @service.get_claims_by_date_range({
                                                           'start_date' => '2024-01-01T16:45:34Z',
                                                           'end_date' => '2024-03-01T16:45:34Z'
                                                         })

      expect(claims_by_date[:data].count).to equal(0)
      expect(claims_by_date[:metadata]['totalRecordCount']).to equal(0)
    end

    it 'raises an exception if error and no claims returned' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token], {
                start_date: '2024-01-01T16:45:34Z',
                end_date: '2024-03-01T16:45:34Z',
                page_size: 1,
                page_number: 1
              })
        .and_raise(Common::Exceptions::BackendServiceException.new(
                     'VA900',
                     { source: 'test' },
                     401,
                     {
                       'statusCode' => 401,
                       'message' => 'Unauthorized.',
                       'success' => false,
                       'data' => nil
                     }
                   ))

      expect do
        @service.get_claims_by_date_range({
                                            'start_date' => '2024-01-01T16:45:34Z',
                                            'end_date' => '2024-03-01T16:45:34Z',
                                            'page_size' => 1
                                          })
      end.to raise_error(Common::Exceptions::BackendServiceException)
    end

    it 'returns partial success if some claims returned' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token], {
                start_date: '2024-01-01T16:45:34Z',
                end_date: '2024-03-01T16:45:34Z',
                page_size: 1,
                page_number: 1
              })
        .and_return(claims_by_date_response1)
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token], {
                start_date: '2024-01-01T16:45:34Z',
                end_date: '2024-03-01T16:45:34Z',
                page_size: 1,
                page_number: 2
              })
        .and_raise(Common::Exceptions::BackendServiceException.new(
                     'VA900',
                     { source: 'test' },
                     401,
                     {
                       'statusCode' => 401,
                       'message' => 'Unauthorized.',
                       'success' => false,
                       'data' => nil
                     }
                   ))

      claims_by_date = @service.get_claims_by_date_range({
                                                           'start_date' => '2024-01-01T16:45:34Z',
                                                           'end_date' => '2024-03-01T16:45:34Z',
                                                           'page_size' => 1
                                                         })
      expect(claims_by_date[:data].count).to equal(1)
      expect(claims_by_date[:metadata]['totalRecordCount']).to equal(3)
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
      @service = TravelPay::ClaimsService.new(auth_manager, user)
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
      @service = TravelPay::ClaimsService.new(auth_manager, user)
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
