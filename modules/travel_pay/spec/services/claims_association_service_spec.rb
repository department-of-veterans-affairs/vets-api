# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

describe TravelPay::ClaimAssociationService do
  context 'associate_appointments_to_claims' do
    let(:user) { build(:user) }
    let(:claims_data_success) do
      {
        metadata: {
          'status' => 200,
          'message' => 'Data retrieved successfully.',
          'success' => true
        },
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
          'id' => '32073',
          'kind' => 'clinic',
          'status' => 'cancelled',
          'patientIcn' => '1012845331V153043',
          'locationId' => '983',
          'clinic' => '408',
          'start' => '2021-06-02T16:00:00Z',
          'cancellable' => false
        }
      ] }
    end

    let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }
    let(:expected_uuids) { %w[uuid1] }

    before do
      auth_manager = object_double(TravelPay::AuthManager.new(123, user), authorize: tokens)
      @service = TravelPay::ClaimsService.new(auth_manager)
    end

    it 'returns appointments with matched claims' do
      allow_any_instance_of(TravelPay::ClaimsService)
        .to receive(:get_claims_by_date_range)
        .with(
          { 'start_date' => '2024-01-01T16:45:00Z',
            'end_date' => '2024-01-15T16:45:00Z' }
        )
        .and_return(claims_data_success)

      association_service = TravelPay::ClaimAssociationService.new
      appts_with_claims = association_service.associate_appointments_to_claims({ 'appointments' => appointments,
                                                                                 'start_date' => '2024-01-01T16:45:00Z',
                                                                                 'end_date' => '2024-01-15T16:45:00Z' })

      actual_appts_with_claims = appts_with_claims.filter do |c|
        c['associatedTravelPayClaim']['claim']
      end

      expect(appts_with_claims.count).to eq(appointments['data'].count)
      appts_with_claims.each do |appt|
        expect(appt['associatedTravelPayClaim']['metadata']['status']).to eq(200)
        expect(appt['associatedTravelPayClaim']['metadata']['message']).to eq('Data retrieved successfully.')
        expect(appt['associatedTravelPayClaim']['metadata']['success']).to eq(true)
      end
      expect(actual_appts_with_claims.count).to equal(1)
      expect(actual_appts_with_claims[0]['associatedTravelPayClaim']['claim']['id']).to eq(expected_uuids[0])
    end

    it 'returns appointments with error metadata if claims call fails' do
      allow_any_instance_of(TravelPay::ClaimsService)
        .to receive(:get_claims_by_date_range)
        .with(
          { 'start_date' => '2024-01-01T16:45:00Z',
            'end_date' => '2024-01-15T16:45:00Z' }
        )
        .and_return(nil)

      association_service = TravelPay::ClaimAssociationService.new
      appts_with_claims = association_service.associate_appointments_to_claims({ 'appointments' => appointments,
                                                                                 'start_date' => '2024-01-01T16:45:00Z',
                                                                                 'end_date' => '2024-01-15T16:45:00Z' })

      expect(appts_with_claims.count).to eq(appointments['data'].count)
      expect(appts_with_claims.find do |c|
        c['associatedTravelPayClaim']['claim']
      end).to be_nil
      appts_with_claims.each do |appt|
        expect(appt['associatedTravelPayClaim']['metadata']['status']).to equal(503)
        expect(appt['associatedTravelPayClaim']['metadata']['message']).to eq('Travel Pay service unavailable.')
        expect(appt['associatedTravelPayClaim']['metadata']['success']).to eq(false)
      end
    end
  end

  context 'associate_appointment_to_claim' do
    let(:user) { build(:user) }
    let(:single_claim_data_success) do
      {
        metadata: {
          'status' => 200,
          'message' => 'Data retrieved successfully.',
          'success' => true
        },
        data: [
          {
            'id' => 'uuid1',
            'claimNumber' => 'TC0000000000001',
            'claimStatus' => 'InProgress',
            'appointmentDateTime' => '2024-01-01T16:45:34Z',
            'facilityName' => 'Cheyenne VA Medical Center',
            'createdOn' => '2024-03-22T21:22:34.465Z',
            'modifiedOn' => '2024-01-01T16:44:34.465Z'
          }
        ]
      }
    end

    let(:no_claim_data_success) do
      {
        metadata: {
          'status' => 200,
          'message' => 'Data retrieved successfully.',
          'success' => true
        },
        data: []
      }
    end

    let(:single_appointment) do
      {
        'id' => '32066',
        'kind' => 'clinic',
        'status' => 'cancelled',
        'patientIcn' => '1012845331V153043',
        'locationId' => '983',
        'clinic' => '1081',
        'start' => '2024-01-01T16:45:34Z',
        'cancellable' => false
      }
    end

    let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

    before do
      auth_manager = object_double(TravelPay::AuthManager.new(123, user), authorize: tokens)
      @service = TravelPay::ClaimsService.new(auth_manager)
    end

    it 'returns an appointment with a claim' do
      allow_any_instance_of(TravelPay::ClaimsService)
        .to receive(:get_claims_by_date_range)
        .with(
          { 'start_date' => '2024-01-01T16:45:34Z',
            'end_date' => '2024-01-01T16:45:34Z' }
        )
        .and_return(single_claim_data_success)

      association_service = TravelPay::ClaimAssociationService.new
      appt_with_claim = association_service.associate_appointment_to_claim({ 'appointment' => single_appointment })

      expect(appt_with_claim['associatedTravelPayClaim']['metadata']['status']).to eq(200)
      expect(appt_with_claim['associatedTravelPayClaim']['metadata']['message']).to eq('Data retrieved successfully.')
      expect(appt_with_claim['associatedTravelPayClaim']['metadata']['success']).to eq(true)
      expect(appt_with_claim['associatedTravelPayClaim']['claim']).to eq(single_claim_data_success[:data][0])
    end

    it 'returns an appointment with success metadata but no claim' do
      allow_any_instance_of(TravelPay::ClaimsService)
        .to receive(:get_claims_by_date_range)
        .with(
          { 'start_date' => '2024-01-01T16:45:34Z',
            'end_date' => '2024-01-01T16:45:34Z' }
        )
        .and_return(no_claim_data_success)

      association_service = TravelPay::ClaimAssociationService.new
      appt_with_claim = association_service.associate_appointment_to_claim({ 'appointment' => single_appointment })

      expect(appt_with_claim['associatedTravelPayClaim']['metadata']['status']).to eq(200)
      expect(appt_with_claim['associatedTravelPayClaim']['metadata']['message']).to eq('Data retrieved successfully.')
      expect(appt_with_claim['associatedTravelPayClaim']['metadata']['success']).to eq(true)
      expect(appt_with_claim['associatedTravelPayClaim']['claim']).to be_nil
    end

    it 'returns appointment with error metadata if claims call fails' do
      allow_any_instance_of(TravelPay::ClaimsService)
        .to receive(:get_claims_by_date_range)
        .with(
          { 'start_date' => '2024-01-01T16:45:34Z',
            'end_date' => '2024-01-01T16:45:34Z' }
        )
        .and_return(nil)

      association_service = TravelPay::ClaimAssociationService.new
      appt_with_claim = association_service.associate_appointment_to_claim({ 'appointment' => single_appointment })

      expect(appt_with_claim['associatedTravelPayClaim']['claim']).to be_nil
      expect(appt_with_claim['associatedTravelPayClaim']['metadata']['status']).to equal(503)
      expect(appt_with_claim['associatedTravelPayClaim']['metadata']['message']).to eq('Travel Pay service unavailable.')
      expect(appt_with_claim['associatedTravelPayClaim']['metadata']['success']).to eq(false)
    end
  end
end
