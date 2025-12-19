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
    let(:auth_manager) { object_double(TravelPay::AuthManager.new(123, user), authorize: tokens) }
    let(:service) { TravelPay::ClaimsService.new(auth_manager, user) }

    before do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims)
        .and_return(claims_response)
    end

    it 'returns sorted and parsed claims' do
      expected_statuses = ['In progress', 'In progress', 'Incomplete', 'Claim submitted']

      claims = service.get_claims({})
      actual_statuses = claims[:data].pluck('claimStatus')

      expect(actual_statuses).to match_array(expected_statuses)
    end

    it 'passes default params' do
      expected_statuses = ['In progress', 'In progress', 'Incomplete', 'Claim submitted']
      expect_any_instance_of(TravelPay::ClaimsClient).to receive(:get_claims).with(tokens[:veis_token],
                                                                                   tokens[:btsss_token],
                                                                                   { page_size: 50, page_number: 1 })
      claims = service.get_claims({})
      actual_statuses = claims[:data].pluck('claimStatus')

      expect(actual_statuses).to match_array(expected_statuses)
    end

    it 'passes params that were given' do
      expected_statuses = ['In progress', 'In progress', 'Incomplete', 'Claim submitted']
      expect_any_instance_of(TravelPay::ClaimsClient).to receive(:get_claims).with(tokens[:veis_token],
                                                                                   tokens[:btsss_token],
                                                                                   { page_size: 10, page_number: 2 })
      claims = service.get_claims({ 'page_size' => 10, 'page_number' => 2 })
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
    let(:auth_manager) { object_double(TravelPay::AuthManager.new(123, user), authorize: tokens) }
    let(:service) { TravelPay::ClaimsService.new(auth_manager, user) }

    before do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claim_by_id)
        .and_return(claim_details_response)

      allow_any_instance_of(TravelPay::DocumentsClient)
        .to receive(:get_document_ids)
        .and_return(document_ids_response)
    end

    it 'returns expanded claim details when passed a valid id' do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_claims_management, instance_of(User)).and_return(false)
      claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
      actual_claim = service.get_claim_details(claim_id)

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
      actual_claim = service.get_claim_details(claim_id)

      expect(actual_claim['documents']).to be_empty
      expect(actual_claim['expenses']).not_to be_empty
      expect(actual_claim['appointment']).not_to be_empty
      expect(actual_claim['totalCostRequested']).to eq(20.00)
      expect(actual_claim['claimStatus']).to eq('Pre approved for payment')
    end

    it 'includes document summary info when include_documents flag is true' do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_claims_management, instance_of(User)).and_return(true)
      claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
      actual_claim = service.get_claim_details(claim_id)

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
      expect { service.get_claim_details(claim_id) }
        .to raise_error(Common::Exceptions::ResourceNotFound, /not found/i)
    end

    it 'throws an ArgumentError if claim_id is invalid format' do
      claim_id = 'this-is-definitely-a-uuid-right'

      expect { service.get_claim_details(claim_id) }
        .to raise_error(ArgumentError, /Claim ID is invalid/i)
    end

    it 'overwrites expenseType with name value for parking expenses' do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_claims_management, instance_of(User)).and_return(false)

      # Create claim data with a Parking expense where expenseType is "Other" but name is "Parking"
      claim_data_with_parking = claim_details_data.deep_dup
      claim_data_with_parking['data']['expenses'] = [
        {
          'id' => 'parking-expense-id',
          'expenseType' => 'Other',
          'name' => 'Parking',
          'dateIncurred' => '2024-01-01T16:45:34.465Z',
          'description' => 'parking-expense',
          'costRequested' => 5.00,
          'costSubmitted' => 5.00
        }
      ]

      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claim_by_id)
        .and_return(Faraday::Response.new(body: claim_data_with_parking))

      claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
      actual_claim = service.get_claim_details(claim_id)

      expect(actual_claim['expenses'].first['expenseType']).to eq('Parking')
      expect(actual_claim['expenses'].first['name']).to eq('Parking')
    end

    it 'overwrites expenseType only for parking expenses, not other expense types' do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_claims_management, instance_of(User)).and_return(false)

      claim_data_mixed = claim_details_data.deep_dup
      claim_data_mixed['data']['expenses'] = [
        {
          'id' => 'parking-expense-id',
          'expenseType' => 'Other',
          'name' => 'Parking',
          'dateIncurred' => '2024-01-01T16:45:34.465Z',
          'description' => 'parking-expense',
          'costRequested' => 5.00,
          'costSubmitted' => 5.00
        },
        {
          'id' => 'mileage-expense-id',
          'expenseType' => 'Mileage',
          'name' => 'Mileage Expense',
          'dateIncurred' => '2024-01-01T16:45:34.465Z',
          'description' => 'mileage-expense',
          'costRequested' => 10.00,
          'costSubmitted' => 10.00
        }
      ]

      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claim_by_id)
        .and_return(Faraday::Response.new(body: claim_data_mixed))

      claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
      actual_claim = service.get_claim_details(claim_id)

      # Parking expense should be overwritten
      expect(actual_claim['expenses'][0]['expenseType']).to eq('Parking')
      # Mileage expense should NOT be overwritten
      expect(actual_claim['expenses'][1]['expenseType']).to eq('Mileage')
    end

    it 'does not overwrite expenseType when name is blank' do
      allow(Flipper).to receive(:enabled?).with(:travel_pay_claims_management, instance_of(User)).and_return(false)

      claim_data_blank_name = claim_details_data.deep_dup
      claim_data_blank_name['data']['expenses'] = [
        {
          'id' => 'expense-id',
          'expenseType' => 'Other',
          'name' => '',
          'dateIncurred' => '2024-01-01T16:45:34.465Z',
          'description' => 'some-expense',
          'costRequested' => 5.00,
          'costSubmitted' => 5.00
        }
      ]

      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claim_by_id)
        .and_return(Faraday::Response.new(body: claim_data_blank_name))

      claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
      actual_claim = service.get_claim_details(claim_id)

      expect(actual_claim['expenses'].first['expenseType']).to eq('Other')
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

    let(:claims_all_response) do
      Faraday::Response.new(
        body: {
          'statusCode' => 200,
          'message' => 'No claims found.',
          'success' => true,
          'totalRecordCount' => 3,
          'data' => claims_by_date_data
        }
      )
    end

    let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }
    let(:auth_manager) { object_double(TravelPay::AuthManager.new(123, user), authorize: tokens) }
    let(:service) { TravelPay::ClaimsService.new(auth_manager, user) }

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
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

      claims_by_date = service.get_claims_by_date_range({
                                                          'start_date' => '2024-01-01T16:45:34Z',
                                                          'end_date' => '2024-03-01T16:45:34Z',
                                                          'page_size' => 1
                                                        })

      expect(Rails.logger).to have_received(:info).with(
        message: /Looped through 3 claims in/i
      )
      expect(claims_by_date[:data].pluck('id')).to match_array(expected_ids)
      expect(claims_by_date[:data].count).to equal(claims_by_date[:metadata]['totalRecordCount'])
      expect(claims_by_date[:metadata]['totalRecordCount']).to equal(3)
      expect(claims_by_date[:metadata]['status']).to equal(200)
      expect(claims_by_date[:metadata]['pageNumber']).to equal(3)
    end

    it 'uses all defaults if no params are passed in' do
      Timecop.freeze(DateTime.new(2024, 4, 1).utc)
      expected_ids = %w[uuid1 uuid2 uuid3]
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .and_return(claims_all_response)

      expect_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token], {
                start_date: '2024-01-01T00:00:00Z',
                end_date: '2024-04-01T00:00:00Z',
                page_size: 50,
                page_number: 1
              }).once # since the default page size is > claims, it should not loop and only call the client once

      claims_by_date = service.get_claims_by_date_range({})

      expect(claims_by_date[:data].pluck('id')).to match_array(expected_ids)
      expect(claims_by_date[:data].count).to equal(claims_by_date[:metadata]['totalRecordCount'])
      expect(claims_by_date[:metadata]['totalRecordCount']).to equal(3)
      expect(claims_by_date[:metadata]['status']).to equal(200)
      expect(claims_by_date[:metadata]['pageNumber']).to equal(1)
      expect(Rails.logger).to have_received(:info).with(
        message: /Looped through 3 claims in/i
      )
    end

    it 'returns a single claim if dates are the same' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .and_return(single_claim_by_date_response)

      claims_by_date = service.get_claims_by_date_range({
                                                          'start_date' => '2024-01-01T16:45:34Z',
                                                          'end_date' => '2024-01-01T16:45:34Z'
                                                        })

      expect(claims_by_date[:data].count).to equal(claims_by_date[:metadata]['totalRecordCount'])
      expect(Rails.logger).to have_received(:info).with(
        message: /Looped through 1 claims in/i
      )
    end

    it 'throws an Argument exception if both start and end dates are not provided' do
      expect { service.get_claims_by_date_range({ 'start_date' => '2024-01-01T16:45:34.465Z' }) }
        .to raise_error(ArgumentError, /Both start and end/i)
    end

    it 'throws an exception if dates are invalid' do
      expect do
        service.get_claims_by_date_range(
          { 'start_date' => '2024-01-01T16:45:34.465Z', 'end_date' => 'banana' }
        )
      end
        .to raise_error(ArgumentError, /no time information/i)
    end

    it 'returns success but empty array if no claims found' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .and_return(claims_no_data_response)

      claims_by_date = service.get_claims_by_date_range({
                                                          'start_date' => '2024-01-01T16:45:34Z',
                                                          'end_date' => '2024-03-01T16:45:34Z'
                                                        })

      expect(claims_by_date[:data].count).to equal(0)
      expect(claims_by_date[:metadata]['totalRecordCount']).to equal(0)
      expect(Rails.logger).to have_received(:info).with(
        message: /Looped through 0 claims in/i
      )
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
        service.get_claims_by_date_range({
                                           'start_date' => '2024-01-01T16:45:34Z',
                                           'end_date' => '2024-03-01T16:45:34Z',
                                           'page_size' => 1
                                         })
      end.to raise_error(Common::Exceptions::BackendServiceException)
      expect(Rails.logger).to have_received(:error).with(
        message: /Could not retrieve claim/i
      )
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

      claims_by_date = service.get_claims_by_date_range({
                                                          'start_date' => '2024-01-01T16:45:34Z',
                                                          'end_date' => '2024-03-01T16:45:34Z',
                                                          'page_size' => 1
                                                        })
      expect(Rails.logger).to have_received(:error).with(
        message: /Retrieved 1 of 3 claims/i
      )
      expect(Rails.logger).to have_received(:info).with(
        message: /Looped through 1 claims in/i
      )
      expect(claims_by_date[:data].count).to equal(1)
      expect(claims_by_date[:metadata]['totalRecordCount']).to equal(3)
      expect(claims_by_date[:metadata]['pageNumber']).to equal(1)
      expect(claims_by_date[:metadata]['status']).to equal(206)
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
    let(:auth_manager) { object_double(TravelPay::AuthManager.new(123, user), authorize: tokens) }
    let(:service) { TravelPay::ClaimsService.new(auth_manager, user) }

    it 'returns a claim ID when passed a valid btsss appt id' do
      btsss_appt_id = '73611905-71bf-46ed-b1ec-e790593b8565'
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:create_claim)
        .with(tokens[:veis_token], tokens[:btsss_token], { 'btsss_appt_id' => btsss_appt_id,
                                                           'claim_name' => 'SMOC claim' })
        .and_return(new_claim_response)

      actual_claim_response = service.create_new_claim({
                                                         'btsss_appt_id' => btsss_appt_id,
                                                         'claim_name' => 'SMOC claim'
                                                       })
      expect(actual_claim_response).to equal(new_claim_data['data'])
    end

    it 'throws an ArgumentException if btsss_appt_id is invalid format' do
      btsss_appt_id = 'this-is-definitely-a-uuid-right'

      expect { service.create_new_claim({ 'btsss_appt_id' => btsss_appt_id }) }
        .to raise_error(ArgumentError, /valid UUID/i)

      expect { service.create_new_claim({ 'btsss_appt_id' => nil }) }
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
    let(:auth_manager) { object_double(TravelPay::AuthManager.new(123, user), authorize: tokens) }
    let(:service) { TravelPay::ClaimsService.new(auth_manager, user) }

    it 'returns submitted claim information' do
      expect_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:submit_claim).once
        .and_return(response)

      service.submit_claim('3fa85f64-5717-4562-b3fc-2c963f66afa6')
    end

    it 'raises an error if claim_id is missing' do
      expect { service.submit_claim }.to raise_error(ArgumentError)
    end

    it 'raises an error if invalid claim_id provided' do
      # present, wrong format
      expect { service.submit_claim('claim_numero_uno') }.to raise_error(ArgumentError)

      # empty
      expect { service.submit_claim('') }.to raise_error(ArgumentError)
    end
  end

  context 'decision letter functionality' do
    let(:user) { build(:user) }
    let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }
    let(:auth_manager) { object_double(TravelPay::AuthManager.new(123, user), authorize: tokens) }
    let(:service) { TravelPay::ClaimsService.new(auth_manager, user) }

    describe '#find_decision_letter_document' do
      it 'finds decision letter document when filename contains "Decision Letter"' do
        claim = {
          'documents' => [
            { 'filename' => 'receipt.pdf' },
            { 'filename' => 'Decision Letter.docx', 'documentId' => 'decision_doc_id' },
            { 'filename' => 'other.pdf' }
          ]
        }

        result = service.send(:find_decision_letter_document, claim)
        expect(result['documentId']).to eq('decision_doc_id')
        expect(result['filename']).to eq('Decision Letter.docx')
      end

      it 'finds rejection letter document when filename contains "Rejection Letter"' do
        claim = {
          'documents' => [
            { 'filename' => 'receipt.pdf' },
            { 'filename' => 'Rejection Letter.docx', 'documentId' => 'rejection_doc_id' },
            { 'filename' => 'other.pdf' }
          ]
        }

        result = service.send(:find_decision_letter_document, claim)
        expect(result['documentId']).to eq('rejection_doc_id')
        expect(result['filename']).to eq('Rejection Letter.docx')
      end

      it 'returns nil when no decision or rejection letter is found' do
        claim = {
          'documents' => [
            { 'filename' => 'receipt.pdf' },
            { 'filename' => 'other.pdf' }
          ]
        }

        result = service.send(:find_decision_letter_document, claim)
        expect(result).to be_nil
      end

      it 'returns nil when documents array is empty' do
        claim = { 'documents' => [] }

        result = service.send(:find_decision_letter_document, claim)
        expect(result).to be_nil
      end

      it 'returns nil when documents key is missing' do
        claim = {}

        result = service.send(:find_decision_letter_document, claim)
        expect(result).to be_nil
      end

      it 'handles case insensitive matching' do
        claim = {
          'documents' => [
            { 'filename' => 'decision letter.pdf', 'documentId' => 'decision_doc_id' }
          ]
        }

        result = service.send(:find_decision_letter_document, claim)
        expect(result['documentId']).to eq('decision_doc_id')
      end

      it 'returns nil when decision letter document has no documentId' do
        claim = {
          'documents' => [
            { 'filename' => 'Decision Letter.docx' }
          ]
        }

        result = service.send(:find_decision_letter_document, claim)
        expect(result).to be_nil
      end

      it 'returns nil when decision letter document has empty documentId' do
        claim = {
          'documents' => [
            { 'filename' => 'Decision Letter.docx', 'documentId' => '' }
          ]
        }

        result = service.send(:find_decision_letter_document, claim)
        expect(result).to be_nil
      end

      it 'returns nil when decision letter document has nil documentId' do
        claim = {
          'documents' => [
            { 'filename' => 'Decision Letter.docx', 'documentId' => nil }
          ]
        }

        result = service.send(:find_decision_letter_document, claim)
        expect(result).to be_nil
      end
    end

    describe 'integration with get_claim_details' do
      let(:claim_details_data_denied) do
        {
          'data' => {
            'claimId' => '73611905-71bf-46ed-b1ec-e790593b8565',
            'claimStatus' => 'Denied',
            'claimNumber' => 'TC0000000000001'
          }
        }
      end

      let(:claim_details_data_partial) do
        {
          'data' => {
            'claimId' => '73611905-71bf-46ed-b1ec-e790593b8565',
            'claimStatus' => 'PartialPayment',
            'claimNumber' => 'TC0000000000001'
          }
        }
      end

      let(:claim_details_data_approved) do
        {
          'data' => {
            'claimId' => '73611905-71bf-46ed-b1ec-e790593b8565',
            'claimStatus' => 'PreApprovedForPayment',
            'claimNumber' => 'TC0000000000001'
          }
        }
      end

      let(:documents_with_decision_letter) do
        {
          'data' => [
            {
              'documentId' => 'decision_doc_id',
              'id' => 'decision_doc_id',
              'filename' => 'Decision Letter.docx',
              'mimetype' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
              'createdon' => '2025-03-24T14:00:52.893Z'
            }
          ]
        }
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:travel_pay_claims_management, user).and_return(true)
        allow_any_instance_of(TravelPay::DocumentsClient)
          .to receive(:get_document_ids)
          .and_return(double(body: documents_with_decision_letter))
      end

      context 'when travel_pay_claims_management_decision_reason_api feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:travel_pay_claims_management_decision_reason_api,
                                                    user).and_return(true)
        end

        it 'includes decision_letter_reason for denied claims' do
          allow_any_instance_of(TravelPay::ClaimsClient)
            .to receive(:get_claim_by_id)
            .and_return(double(body: claim_details_data_denied))

          # Mock the DocReader-based decision reason extraction
          mock_doc_reader = instance_double(TravelPay::DocReader)
          allow(TravelPay::DocReader).to receive(:new).and_return(mock_doc_reader)
          allow(mock_doc_reader).to receive_messages(
            denial_reasons: 'Authority 38 CFR 17.120 - Insufficient documentation', partial_payment_reasons: nil
          )

          mock_documents_service = instance_double(TravelPay::DocumentsService)
          allow(TravelPay::DocumentsService).to receive(:new).and_return(mock_documents_service)
          allow(mock_documents_service).to receive(:download_document).and_return({ body: 'mock_doc_data' })

          claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
          result = service.get_claim_details(claim_id)

          expect(result['decision_letter_reason']).to eq('Authority 38 CFR 17.120 - Insufficient documentation')
          expect(result['claimStatus']).to eq('Denied')
        end

        it 'does not include decision_letter_reason for partial payment claims (due to bug in status transformation)' do
          allow_any_instance_of(TravelPay::ClaimsClient)
            .to receive(:get_claim_by_id)
            .and_return(double(body: claim_details_data_partial))

          claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
          result = service.get_claim_details(claim_id)

          # Due to a bug in the service, the status is transformed before checking the condition
          # 'PartialPayment' becomes 'Partial payment' but the condition checks for 'PartialPayment'
          expect(result).not_to have_key('decision_letter_reason')
          expect(result['claimStatus']).to eq('Partial payment')
        end

        it 'does not include decision_letter_reason for approved claims' do
          allow_any_instance_of(TravelPay::ClaimsClient)
            .to receive(:get_claim_by_id)
            .and_return(double(body: claim_details_data_approved))

          claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
          result = service.get_claim_details(claim_id)

          expect(result).not_to have_key('decision_letter_reason')
          expect(result['claimStatus']).to eq('Pre approved for payment')
        end

        it 'does not include decision_letter_reason when no decision letter document found' do
          allow_any_instance_of(TravelPay::ClaimsClient)
            .to receive(:get_claim_by_id)
            .and_return(double(body: claim_details_data_denied))

          # Mock no decision letter document
          allow_any_instance_of(TravelPay::DocumentsClient)
            .to receive(:get_document_ids)
            .and_return(double(body: { 'data' => [{ 'documentId' => 'other_doc', 'filename' => 'receipt.pdf' }] }))

          claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
          result = service.get_claim_details(claim_id)

          expect(result).not_to have_key('decision_letter_reason')
          expect(result['claimStatus']).to eq('Denied')
        end
      end

      context 'when travel_pay_claims_management_decision_reason_api feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:travel_pay_claims_management_decision_reason_api,
                                                    user).and_return(false)
        end

        it 'does not include decision_letter_reason for denied claims when feature flag is disabled' do
          allow_any_instance_of(TravelPay::ClaimsClient)
            .to receive(:get_claim_by_id)
            .and_return(double(body: claim_details_data_denied))

          claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
          result = service.get_claim_details(claim_id)

          expect(result).not_to have_key('decision_letter_reason')
          expect(result['claimStatus']).to eq('Denied')
        end

        it 'does not include decision_letter_reason for paid claims when feature flag is disabled' do
          paid_claim_data = {
            'data' => {
              'claimId' => '73611905-71bf-46ed-b1ec-e790593b8565',
              'claimStatus' => 'Paid',
              'claimNumber' => 'TC0000000000001'
            }
          }

          allow_any_instance_of(TravelPay::ClaimsClient)
            .to receive(:get_claim_by_id)
            .and_return(double(body: paid_claim_data))

          claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
          result = service.get_claim_details(claim_id)

          expect(result).not_to have_key('decision_letter_reason')
          expect(result['claimStatus']).to eq('Paid')
        end
      end
    end
  end
end
