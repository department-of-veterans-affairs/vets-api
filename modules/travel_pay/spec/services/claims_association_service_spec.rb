# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

describe TravelPay::ClaimsService do
  context 'get_claims' do
    let(:user) { build(:user) }
    let(:claims_data) do
      {
        data: [
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

    let(:appointments) do
      { 'data' =>
      [
        {
          'id' => '32066',
          'kind' => 'clinic',
          'status' => 'cancelled',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'clinic' => '1081',
          'start' => '2024-01-01T16:45:34Z',
          'cancellable' => false
        },
        {
          'id' => '32067',
          'kind' => 'clinic',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'clinic' => '621',
          'start' => '2021-05-20T14:10:00Z',
          'end' => '2021-05-20T14:20:00Z',
          'minutesDuration' => 10,
          'slot' => { 'id' => '3230323130353230313431303A323032313035323031343230',
                      'start' => '2021-05-20T14:10:00Z',
                      'end' => '2021-05-20T14:20:00Z' },
          'cancellable' => true
        },
        {
          'id' => '32068',
          'kind' => 'clinic',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'clinic' => '1038',
          'start' => '2021-05-25T14:30:00Z',
          'end' => '2021-05-25T14:45:00Z',
          'minutesDuration' => 15,
          'slot' => {
            'id' => '3230323130353235313433303A323032313035323531343435',
            'start' => '2021-05-25T14:30:00Z',
            'end' => '2021-05-25T14:45:00Z'
          },
          'cancellable' => true
        },
        {
          'id' => '32069',
          'kind' => 'clinic',
          'status' => 'cancelled',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'clinic' => '455',
          'start' => '2021-05-26T16:15:00Z',
          'cancellable' => false
        },
        {
          'id' => '32070',
          'kind' => 'clinic',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'clinic' => '455',
          'start' => '2021-05-26T20:15:00Z',
          'end' => '2021-05-26T21:15:00Z',
          'minutesDuration' => 60,
          'slot' => { 'id' => '3230323130353236323031353A323032313035323632313135',
                      'start' => '2021-05-26T20:15:00Z',
                      'end' => '2021-05-26T21:15:00Z' },
          'comment' => 'testing',
          'cancellable' => true
        },
        {
          'id' => '32071',
          'kind' => 'clinic',
          'status' => 'cancelled',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'clinic' => '707',
          'start' => '2021-05-28T16:45:00Z',
          'cancellable' => false
        },
        {
          'id' => '32072',
          'kind' => 'clinic',
          'status' => 'cancelled',
          'patientIcn' => '1012845331V153043',
          'locationId' => '984',
          'clinic' => '3009',
          'start' => '2021-06-01T18:00:00Z',
          'cancellable' => false
        },
        {
          'id' => '32073',
          'kind' => 'clinic',
          'status' => 'cancelled',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'clinic' => '408',
          'start' => '2021-06-02T16:00:00Z',
          'cancellable' => false
        },
        {
          'id' => '32074',
          'kind' => 'clinic',
          'status' => 'cancelled',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'clinic' => '1111',
          'start' => '2021-06-02T16:30:00Z',
          'cancellable' => false
        },
        {
          'id' => '32075',
          'kind' => 'telehealth',
          'status' => 'booked',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'telehealth' => { 'url' => 'https://care2.evn.va.gov/vvc-app/?join=1&media=1&escalate=1&conference=VAC000415415@care2.evn.va.gov&pin=869715#&aid=a5dffa35-c805-4db9-9281-6d247c54cfa9' },
          'practitioners' => [{ 'id' => { 'system' => 'dfn-983',
                                          'value' => '520647797' },
                                'firstName' => 'ELIZABETH',
                                'lastName' => 'WODZINSKI',
                                'practiceName' => 'CHEYENNE VAMC' }],
          'start' => '2021-06-02T19:50:00Z',
          'end' => '2021-06-02T20:10:00Z',
          'minutesDuration' => 20,
          'cancellable' => true
        },
        {
          'id' => '32076',
          'kind' => 'telehealth',
          'status' => 'booked',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'telehealth' => { 'url' => 'https://care2.evn.va.gov/vvc-app/?join=1&media=1&escalate=1&conference=VAC000415416@care2.evn.va.gov&pin=824734#&aid=189faec6-2506-4547-abff-fe641bba21aa' },
          'practitioners' => [{ 'id' => { 'system' => 'dfn-983',
                                          'value' => '520647797' },
                                'firstName' => 'ELIZABETH',
                                'lastName' => 'WODZINSKI',
                                'practiceName' => 'CHEYENNE VAMC' }],
          'start' => '2021-06-02T20:30:00Z',
          'end' => '2021-06-02T20:50:00Z',
          'minutesDuration' => 20,
          'cancellable' => true
        },
        {
          'id' => '32077',
          'kind' => 'telehealth',
          'status' => 'booked',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'telehealth' => { 'url' => 'https://care2.evn.va.gov/vvc-app/?join=1&media=1&escalate=1&conference=VAC000415418@care2.evn.va.gov&pin=106524#&aid=1d85fe56-7df3-4911-9728-c95a801b2153' },
          'practitioners' => [{ 'id' => { 'system' => 'dfn-983',
                                          'value' => '520647363' },
                                'firstName' => 'MARCY',
                                'lastName' => 'NADEAU',
                                'practiceName' => 'CHEYENNE VAMC' }],
          'start' => '2021-06-02T20:45:00Z',
          'end' => '2021-06-02T21:05:00Z',
          'minutesDuration' => 20,
          'cancellable' => true
        },
        {
          'id' => '32078',
          'kind' => 'clinic',
          'status' => 'cancelled',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'clinic' => '945',
          'start' => '2021-06-03T16:00:00Z',
          'cancellable' => false
        },
        {
          'id' => '32079',
          'kind' => 'clinic',
          'status' => 'cancelled',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'clinic' => '1111',
          'start' => '2021-06-03T18:30:00Z',
          'cancellable' => false
        },
        {
          'id' => '32080',
          'kind' => 'telehealth',
          'status' => 'booked',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'telehealth' => { 'url' => 'https://care2.evn.va.gov/vvc-app/?join=1&media=1&escalate=1&conference=VAC000415417@care2.evn.va.gov&pin=470163#&aid=26bd6957-20ea-4c33-abd7-75f1a65d5b7e' },
          'practitioners' => [{ 'id' => { 'system' => 'dfn-983',
                                          'value' => '520647363' },
                                'firstName' => 'MARCY',
                                'lastName' => 'NADEAU',
                                'practiceName' => 'CHEYENNE VAMC' }],
          'start' => '2021-06-03T20:20:00Z',
          'end' => '2021-06-03T20:40:00Z',
          'minutesDuration' => 20,
          'cancellable' => true
        },
        {
          'id' => '32081',
          'kind' => 'telehealth',
          'status' => 'booked',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'telehealth' => { 'url' => 'https://care2.evn.va.gov/vvc-app/?join=1&media=1&escalate=1&conference=VAC000415419@care2.evn.va.gov&pin=862283#&aid=f3b825e7-05e4-4362-8222-a38ac720afc2' },
          'practitioners' => [{ 'id' => { 'system' => 'dfn-983',
                                          'value' => '520647363' },
                                'firstName' => 'MARCY',
                                'lastName' => 'NADEAU',
                                'practiceName' => 'CHEYENNE VAMC' }],
          'start' => '2021-06-03T20:35:00Z',
          'end' => '2021-06-03T20:55:00Z',
          'minutesDuration' => 20,
          'cancellable' => true
        },
        {
          'id' => '32082',
          'kind' => 'telehealth',
          'status' => 'booked',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'telehealth' => { 'url' => 'https://care2.evn.va.gov/vvc-app/?join=1&media=1&escalate=1&conference=VAC000415414@care2.evn.va.gov&pin=464790#&aid=878261c8-8581-4ab9-a166-623fc0ba8453',
                            'atlas' => { 'siteCode' => '9931',
                                         'confirmationCode' => '420835',
                                         'address' => { 'streetAddress' => '114 Dewey Ave',
                                                        'city' => 'Eureka',
                                                        'state' => 'MT',
                                                        'zipCode' => '59917',
                                                        'country' => 'USA',
                                                        'latitutde' => 48.87956,
                                                        'longitude' => -115.05251,
                                                        'additionalDetails' => '' } } },
          'practitioners' => [{ 'id' => { 'system' => 'dfn-983',
                                          'value' => '520647797' },
                                'firstName' => 'ELIZABETH',
                                'lastName' => 'WODZINSKI',
                                'practiceName' => 'CHEYENNE VAMC' }],
          'start' => '2021-06-04T15:00:00Z',
          'end' => '2021-06-04T15:30:00Z',
          'minutesDuration' => 30,
          'cancellable' => true
        },
        {
          'id' => '32083',
          'kind' => 'clinic',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'clinic' => '707',
          'start' => '2021-06-04T15:45:00Z',
          'end' => '2021-06-04T16:45:00Z',
          'minutesDuration' => 60,
          'slot' => { 'id' => '3230323130363034313534353A323032313036303431363435',
                      'start' => '2021-06-04T15:45:00Z',
                      'end' => '2021-06-04T16:45:00Z' },
          'comment' => 'Medication concern: here is my concern',
          'cancellable' => true
        }
      ] }
    end

    let(:tokens) { %w[veis_token btsss_token] }
    let(:expected_uuids) { %w[uuid1] }

    before do
      allow_any_instance_of(TravelPay::ClaimsService)
        .to receive(:get_claims_by_date_range)
        .with(*tokens,
              { 'start_date' => '2024-01-01T16:45:00Z',
                'end_date' => '2024-15-01T16:45:00Z' })
        .and_return(claims_data)
    end

    it 'returns appointments with matched claims' do
      service = TravelPay::ClaimAssociationService.new
      appts_with_claims = service.associate_appointments_to_claims(tokens, { 'appointments' => appointments,
                                                                             'start_date' => '2024-01-01T16:45:00Z',
                                                                             'end_date' => '2024-15-01T16:45:00Z' })

      actual_appts_with_claims = appts_with_claims.filter { |c| c['associatedTravelPayClaim']['id'] }

      expect(appts_with_claims.count).to eq(appointments['data'].count)
      expect(actual_appts_with_claims.count).to equal(1)
      expect(actual_appts_with_claims[0]['associatedTravelPayClaim']['id']).to eq(expected_uuids[0])
    end
  end
end
