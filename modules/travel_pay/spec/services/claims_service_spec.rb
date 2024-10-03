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

    let(:tokens) { %w[veis_token btsss_token] }

    before do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims)
        .with(*tokens)
        .and_return(claims_response)
    end

    it 'returns sorted and parsed claims' do
      expected_statuses = ['In Progress', 'In Progress', 'Incomplete', 'Claim Submitted']

      service = TravelPay::ClaimsService.new
      claims = service.get_claims(*tokens)
      actual_statuses = claims[:data].pluck('claimStatus')

      expect(actual_statuses).to match_array(expected_statuses)
    end

    context 'get claim by id' do
      it 'returns a single claim when passed a valid id' do
        claim_id = '73611905-71bf-46ed-b1ec-e790593b8565'
        expected_claim = claims_data['data'].find { |c| c['id'] == claim_id }
        service = TravelPay::ClaimsService.new
        actual_claim = service.get_claim_by_id(*tokens, claim_id)

        expect(actual_claim).to eq(expected_claim)
      end

      it 'returns nil if a claim with the given id was not found' do
        claim_id = SecureRandom.uuid
        service = TravelPay::ClaimsService.new
        actual_claim = service.get_claim_by_id(*tokens, claim_id)

        expect(actual_claim).to eq(nil)
      end

      it 'throws an ArgumentException if claim_id is invalid format' do
        claim_id = 'this-is-definitely-a-uuid-right'
        service = TravelPay::ClaimsService.new

        expect { service.get_claim_by_id(*tokens, claim_id) }
          .to raise_error(ArgumentError, /valid UUID/i)
      end
    end

    context 'filter by appt date' do
      it 'returns claims that match appt date if specified' do
        service = TravelPay::ClaimsService.new
        claims = service.get_claims(*tokens, { 'appt_datetime' => '2024-01-01' })

        expect(claims.count).to equal(1)
      end

      it 'returns 0 claims if appt date does not match' do
        service = TravelPay::ClaimsService.new
        claims = service.get_claims(*tokens, { 'appt_datetime' => '1700-01-01' })

        expect(claims[:data].count).to equal(0)
      end

      it 'returns all claims if appt date is invalid' do
        service = TravelPay::ClaimsService.new
        claims = service.get_claims(*tokens, { 'appt_datetime' => 'banana' })

        expect(claims[:data].count).to equal(claims_data['data'].count)
      end

      it 'returns all claims if appt date is not specified' do
        service = TravelPay::ClaimsService.new
        claims_empty_date = service.get_claims(*tokens, { 'appt_datetime' => '' })
        claims_nil_date = service.get_claims(*tokens, { 'appt_datetime' => 'banana' })
        claims_no_param = service.get_claims(*tokens)

        expect(claims_empty_date[:data].count).to equal(claims_data['data'].count)
        expect(claims_nil_date[:data].count).to equal(claims_data['data'].count)
        expect(claims_no_param[:data].count).to equal(claims_data['data'].count)
      end
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

    let(:tokens) { %w[veis_token btsss_token] }

    it 'returns a claim ID when passed a valid btsss appt id' do
      btsss_appt_id = '73611905-71bf-46ed-b1ec-e790593b8565'
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:create_claim)
        .with(*tokens, { 'btsss_appt_id' => btsss_appt_id, 'claim_name' => 'SMOC claim' })
        .and_return(new_claim_response)

      service = TravelPay::ClaimsService.new
      actual_claim_response = service.create_new_claim(*tokens,
                                                       { 'btsss_appt_id' => btsss_appt_id,
                                                         'claim_name' => 'SMOC claim' })

      expect(actual_claim_response['data']).to equal(new_claim_data['data'])
    end

    it 'throws an ArgumentException if btsss_appt_id is invalid format' do
      btsss_appt_id = 'this-is-definitely-a-uuid-right'
      service = TravelPay::ClaimsService.new

      expect { service.create_new_claim(*tokens, { 'btsss_appt_id' => btsss_appt_id }) }
        .to raise_error(ArgumentError, /valid UUID/i)

      expect { service.create_new_claim(*tokens, { 'btsss_appt_id' => nil }) }
        .to raise_error(ArgumentError, /must provide/i)
    end
  end
end
