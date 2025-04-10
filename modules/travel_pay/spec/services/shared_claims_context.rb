# frozen_string_literal: true

RSpec.shared_context 'claims' do
  # Common
  let(:user) { build(:user) }
  let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

  # Data
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

  # Responses
  let(:claims_response) do
    Faraday::Response.new(
      body: claims_data
    )
  end

  let(:claim_details_response) do
    Faraday::Response.new(
      body: claim_details_data
    )
  end

  let(:document_ids_response) do
    Faraday::Response.new(
      body: document_ids_data
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

  let(:claims_by_date_response) do
    Faraday::Response.new(
      body: claims_by_date_data
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

  let(:response) do
    Faraday::Response.new(
      body: { 'data' => { 'claimId' => '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                          'status' => 'InProcess' } }
    )
  end
end
