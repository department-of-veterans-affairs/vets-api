# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

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

    before do
      allow_any_instance_of(TravelPay::Client)
        .to receive(:get_claims)
        .with(user)
        .and_return(claims_response)
    end

    it 'returns sorted and parsed claims' do
      expected_statuses = ['In Progress', 'In Progress', 'Incomplete', 'Claim Submitted']

      service = TravelPay::Service.new
      claims = service.get_claims(user)
      actual_statuses = claims[:data].pluck(:claimStatus)

      expect(actual_statuses).to match_array(expected_statuses)
    end

    context 'get claim by id' do
      it 'returns a single claim when passed a valid id' do
        claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
        expected_claim = claims_data['data'].find { |c| c['id'] == claim_id }
        service = TravelPay::Service.new
        actual_claim = service.get_claim_by_id(user, claim_id)

        expect(actual_claim).to eq(expected_claim)
      end

      it 'returns nil if a claim with the given id was not found' do
        claim_id = SecureRandom.uuid
        service = TravelPay::Service.new
        actual_claim = service.get_claim_by_id(user, claim_id)

        expect(actual_claim).to eq(nil)
      end

      it 'throws an ArgumentException if claim_id is invalid format' do
        claim_id = 'this-is-definitely-a-uuid-right'
        service = TravelPay::Service.new

        expect { service.get_claim_by_id(user, claim_id) }
          .to raise_error(ArgumentError, /valid v4 UUID/i)
      end
    end
  end
end
