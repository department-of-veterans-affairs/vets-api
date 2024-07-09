# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::Service do
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
          }
        ]
      }
    end
    let(:claims_response) do
      Faraday::Response.new(
        body: claims_data
      )
    end

    before do
      allow_any_instance_of(TravelPay::Client)
        .to receive(:get_claims)
        .with(user)
        .and_return(claims_response)
    end

    it 'returns sorted and parsed claims' do
      expected_ordered_ids = %w[uuid2 uuid3 uuid1]
      expected_statuses = ['In Progress', 'Incomplete', 'In Progress']

      service = TravelPay::Service.new
      claims = service.get_claims(user)
      actual_claim_ids = claims[:data].pluck(:id)
      actual_statuses = claims[:data].pluck(:claimStatus)

      expect(actual_claim_ids).to eq(expected_ordered_ids)
      expect(actual_statuses).to eq(expected_statuses)
    end
  end
end
