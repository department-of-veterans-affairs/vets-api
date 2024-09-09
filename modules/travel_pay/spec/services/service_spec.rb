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
          },
          {
            'id' => 'uuid4',
            'claimNumber' => '73611905-71bf-46ed-b1ec-e790593b8565',
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
      actual_statuses = claims[:data].pluck('claimStatus')

      expect(actual_statuses).to match_array(expected_statuses)
    end

    context 'filter by appt date' do
      it 'returns claims that match appt date if specified' do
        service = TravelPay::Service.new
        claims = service.get_claims(user, {'appt_datetime' => '2024-01-01'})

        expect(claims.count).to equal(1)
      end

      it 'returns 0 claims if appt date does not match' do
        service = TravelPay::Service.new
        claims = service.get_claims(user, {'appt_datetime' => '1700-01-01'})

        expect(claims[:data].count).to equal(0)
      end

      it 'returns all claims if appt date is invalid' do
        service = TravelPay::Service.new
        claims = service.get_claims(user, {'appt_datetime' => 'banana'})

        expect(claims[:data].count).to equal(claims_data['data'].count)
      end
      
      it 'returns all clailms if appt date is not specified' do
        service = TravelPay::Service.new
        claims_empty_date = service.get_claims(user, {'appt_datetime' => ''})
        claims_nil_date = service.get_claims(user, {'appt_datetime' => 'banana'})
        claims_no_param = service.get_claims(user)

        expect(claims_empty_date[:data].count).to equal(claims_data['data'].count)
        expect(claims_nil_date[:data].count).to equal(claims_data['data'].count)
        expect(claims_no_param[:data].count).to equal(claims_data['data'].count)
      end
    end
  end
end
