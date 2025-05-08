# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

describe TravelPay::ClaimAssociationService do
  context 'associate_appointments_to_claims' do
    let(:user) { build(:user) }
    let(:claims_data_success) do
      {
        'statusCode' => 200,
        'message' => 'Data retrieved successfully.',
        'success' => true,
        'data' => [
          {
            'id' => 'uuid1',
            'claimNumber' => 'TC0000000000001',
            'claimStatus' => 'InProgress',
            'appointmentDateTime' => '2024-10-17T09:00:00Z',
            'facilityName' => 'Cheyenne VA Medical Center',
            'createdOn' => '2024-03-22T21:22:34.465Z',
            'modifiedOn' => '2024-01-01T16:44:34.465Z'
          },
          {
            'id' => 'uuid2',
            'claimNumber' => 'TC0000000000002',
            'claimStatus' => 'InProgress',
            'appointmentDateTime' => '2024-11-10T16:45:34.465Z',
            'facilityName' => 'Cheyenne VA Medical Center',
            'createdOn' => '2024-02-22T21:22:34.465Z',
            'modifiedOn' => '2024-03-01T00:00:00.0Z'
          },
          {
            'id' => 'uuid3',
            'claimNumber' => 'TC0000000000002',
            'claimStatus' => 'Incomplete',
            'appointmentDateTime' => '2024-11-01T16:45:34.465Z',
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

    let(:appointments) do
      [
        {
          id: '32066',
          kind: 'clinic',
          status: 'cancelled',
          patientIcn: '1012845331V153043',
          locationId: '983',
          clinic: '1081',
          start: '2024-10-17T09:00:00Z',
          local_start_time: '2024-10-17T09:00:00-0700',
          cancellable: false
        },
        {
          id: '32067',
          kind: 'clinic',
          patientIcn: '1012845331V153043',
          locationId: '983',
          clinic: '621',
          start: '2021-05-20T14:10:00Z',
          local_start_time: '2021-05-20T14:10:00Z',
          end: '2021-05-20T14:20:00Z',
          minutesDuration: 10,
          slot: { 'id' => '3230323130353230313431303A323032313035323031343230',
                  'start' => '2021-05-20T14:10:00Z',
                  'end' => '2021-05-20T14:20:00Z' },
          cancellable: true
        },
        {
          id: '32073',
          kind: 'clinic',
          status: 'cancelled',
          patientIcn: '1012845331V153043',
          locationId: '983',
          clinic: '408',
          start: '2021-06-02T16:00:00Z',
          local_start_time: '2021-06-02T16:00:00.000-0400',
          cancellable: false
        }
      ]
    end

    let(:claims_success_response) do
      Faraday::Response.new(
        response_body: claims_data_success,
        status: 200
      )
    end

    let(:expected_uuids) { %w[uuid1] }

    let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

    before do
      allow_any_instance_of(TravelPay::AuthManager)
        .to receive(:authorize)
        .and_return(tokens)
      allow(Settings.travel_pay).to receive_messages(client_number: '12345', mobile_client_number: '56789')
    end

    it 'returns appointments with matched claims' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token],
              { start_date: '2024-10-17T09:00:00Z',
                end_date: '2024-12-15T16:45:00Z' })
        .and_return(claims_success_response)

      association_service = TravelPay::ClaimAssociationService.new(user, 'mobile')
      appts_with_claims = association_service.associate_appointments_to_claims({ 'appointments' => appointments,
                                                                                 'start_date' => '2024-10-17T09:00:00Z',
                                                                                 'end_date' => '2024-12-15T16:45:00Z' })

      actual_appts_with_claims = appts_with_claims.filter do |c|
        c['travelPayClaim']['claim']
      end

      expect(appts_with_claims.count).to eq(appointments.count)
      appts_with_claims.each do |appt|
        expect(appt['travelPayClaim']['metadata']['status']).to eq(200)
        expect(appt['travelPayClaim']['metadata']['message']).to eq('Data retrieved successfully.')
        expect(appt['travelPayClaim']['metadata']['success']).to be(true)
      end
      expect(actual_appts_with_claims.count).to equal(1)
      expect(actual_appts_with_claims[0]['travelPayClaim']['claim']['id']).to eq(expected_uuids[0])
    end

    it 'returns appointments with error metadata if claims call fails' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token],
              { start_date: '2024-10-17T09:00:00Z',
                end_date: '2024-12-15T16:45:00Z' })
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

      association_service = TravelPay::ClaimAssociationService.new(user, 'vagov')
      appts_with_claims = association_service.associate_appointments_to_claims({ 'appointments' => appointments,
                                                                                 'start_date' => '2024-10-17T09:00:00Z',
                                                                                 'end_date' => '2024-12-15T16:45:00Z' })

      expect(appts_with_claims.count).to eq(appointments.count)
      expect(appts_with_claims.find do |c|
        c['travelPayClaim']['claim']
      end).to be_nil
      appts_with_claims.each do |appt|
        expect(appt['travelPayClaim']['metadata']['status']).to equal(401)
        expect(appt['travelPayClaim']['metadata']['message']).to eq('Unauthorized.')
        expect(appt['travelPayClaim']['metadata']['success']).to be(false)
      end
    end

    it 'handles random, unknown errors' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .and_raise(NameError.new('Uninitialized constant.', 'new_constant'))

      association_service = TravelPay::ClaimAssociationService.new(user, 'vagov')
      appts_with_claims = association_service.associate_appointments_to_claims({ 'appointments' => appointments,
                                                                                 'start_date' => '2024-10-17T09:00:00Z',
                                                                                 'end_date' => '2024-12-15T16:45:00Z' })
      appts_with_claims.each do |appt|
        expect(appt['travelPayClaim']['metadata']['status']).to equal(520)
        expect(appt['travelPayClaim']['metadata']['success']).to be(false)
        expect(appt['travelPayClaim']['metadata']['message']).to include(/Uninitialized constant/i)
      end
    end

    it 'returns 400 with message if both start and end dates are not provided' do
      association_service = TravelPay::ClaimAssociationService.new(user, 'vagov')
      appts = association_service.associate_appointments_to_claims({ 'appointments' => appointments,
                                                                     'start_date' => '2024-10-17T09:00:00Z' })

      appts.each do |appt|
        expect(appt['travelPayClaim']['metadata']['status']).to equal(400)
        expect(appt['travelPayClaim']['metadata']['success']).to be(false)
        expect(appt['travelPayClaim']['metadata']['message']).to include(/Both start and end/i)
      end
    end

    it 'returns 400 with error message if dates are invalid' do
      association_service = TravelPay::ClaimAssociationService.new(user, 'vagov')
      appts = association_service.associate_appointments_to_claims({ 'appointments' => appointments,
                                                                     'start_date' => '2024-10-17T09:00:00Z',
                                                                     'end_date' => 'banana' })
      appts.each do |appt|
        expect(appt['travelPayClaim']['metadata']['status']).to equal(400)
        expect(appt['travelPayClaim']['metadata']['success']).to be(false)
      end
    end
  end

  context 'associate_single_appointment_to_claim' do
    let(:user) { build(:user) }
    let(:single_claim_data_success) do
      {
        'statusCode' => 200,
        'message' => 'Data retrieved successfully.',
        'success' => true,
        'data' => [
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

    let(:single_claim_success_response) do
      Faraday::Response.new(
        response_body: single_claim_data_success,
        status: 200
      )
    end

    let(:no_claim_data_success) do
      Faraday::Response.new(
        response_body: {
          'statusCode' => 200,
          'message' => 'Data retrieved successfully.',
          'success' => true,
          'data' => []
        },
        status: 200
      )
    end

    let(:single_appointment) do
      {
        id: '32066',
        kind: 'clinic',
        status: 'cancelled',
        patientIcn: '1012845331V153043',
        locationId: '983',
        clinic: '1081',
        start: '2024-01-01T16:45:34Z',
        local_start_time: '2024-01-01T16:45:34Z',
        cancellable: false
      }
    end

    let(:single_appt_invalid) do
      {
        id: '32066',
        kind: 'clinic',
        status: 'cancelled',
        patientIcn: '1012845331V153043',
        locationId: '983',
        clinic: '1081',
        start: 'banana',
        local_start_time: 'banana, but with a timezone',
        cancellable: false
      }
    end

    let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

    before do
      allow(TravelPay::AuthManager)
      .to receive(:new)
        .and_return(double('AuthManager', authorize: tokens))
      allow(Settings.travel_pay).to receive_messages(client_number: '12345', mobile_client_number: '56789')
    end

    it 'returns an appointment with a claim' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token],
              { start_date: '2024-01-01T16:45:34Z',
                end_date: '2024-01-01T16:45:34Z' })
        .and_return(single_claim_success_response)

      association_service = TravelPay::ClaimAssociationService.new(user, 'vagov')
      appt_with_claim = association_service.associate_single_appointment_to_claim(
        { 'appointment' => single_appointment }
      )

      expect(appt_with_claim['travelPayClaim']['metadata']['status']).to eq(200)
      expect(appt_with_claim['travelPayClaim']['metadata']['message']).to eq('Data retrieved successfully.')
      expect(appt_with_claim['travelPayClaim']['metadata']['success']).to be(true)
      expect(appt_with_claim['travelPayClaim']['claim']['id']).to eq(single_claim_data_success['data'][0]['id'])
    end

    it 'instantiates auth_manager with mobile client number' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token],
              { start_date: '2024-01-01T16:45:34Z',
                end_date: '2024-01-01T16:45:34Z' })
        .and_return(single_claim_success_response)

      expect(TravelPay::AuthManager).to receive(:new)
        .with('56789', user)

      association_service = TravelPay::ClaimAssociationService.new(user, 'mobile')
      appt_with_claim = association_service.associate_single_appointment_to_claim(
        { 'appointment' => single_appointment }
      )

      expect(appt_with_claim['travelPayClaim']['metadata']['status']).to eq(200)
    end

    it 'instantiates auth_manager with vagov client number' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token],
              { start_date: '2024-01-01T16:45:34Z',
                end_date: '2024-01-01T16:45:34Z' })
        .and_return(single_claim_success_response)

      expect(TravelPay::AuthManager).to receive(:new)
      .with('12345', user)

      association_service = TravelPay::ClaimAssociationService.new(user, 'vagov')
      appt_with_claim = association_service.associate_single_appointment_to_claim(
        { 'appointment' => single_appointment }
      )

      expect(appt_with_claim['travelPayClaim']['metadata']['status']).to eq(200)
    end

    it 'returns an appointment with success metadata but no claim' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token],
              { start_date: '2024-01-01T16:45:34Z',
                end_date: '2024-01-01T16:45:34Z' })
        .and_return(no_claim_data_success)

      association_service = TravelPay::ClaimAssociationService.new(user, 'vagov')
      appt_with_claim = association_service.associate_single_appointment_to_claim(
        { 'appointment' => single_appointment }
      )

      expect(appt_with_claim['travelPayClaim']['metadata']['status']).to eq(200)
      expect(appt_with_claim['travelPayClaim']['metadata']['message']).to eq('Data retrieved successfully.')
      expect(appt_with_claim['travelPayClaim']['metadata']['success']).to be(true)
      expect(appt_with_claim['travelPayClaim']['claim']).to be_nil
    end

    it 'returns appointment with error metadata if claims call fails' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .with(tokens[:veis_token], tokens[:btsss_token],
              { start_date: '2024-01-01T16:45:34Z',
                end_date: '2024-01-01T16:45:34Z' })
        .and_raise(Common::Exceptions::BackendServiceException.new(
                     'VA900',
                     { source: 'test' },
                     401,
                     {
                       'statusCode' => 401,
                       'message' => 'A contact with the specified ICN was not found.',
                       'success' => false,
                       'data' => nil
                     }
                   ))

      association_service = TravelPay::ClaimAssociationService.new(user, 'vagov')
      appt_with_claim = association_service.associate_single_appointment_to_claim(
        { 'appointment' => single_appointment }
      )

      expect(appt_with_claim['travelPayClaim']['claim']).to be_nil
      expect(appt_with_claim['travelPayClaim']['metadata']['status']).to equal(401)
      expect(appt_with_claim['travelPayClaim']['metadata']['message'])
        .to eq('A contact with the specified ICN was not found.')
      expect(appt_with_claim['travelPayClaim']['metadata']['success']).to be(false)
    end

    it 'handles random, unknown errors' do
      allow_any_instance_of(TravelPay::ClaimsClient)
        .to receive(:get_claims_by_date)
        .and_raise(NameError.new('Uninitialized constant.', 'new_constant'))

      association_service = TravelPay::ClaimAssociationService.new(user, 'vagov')
      appt_with_claim = association_service.associate_single_appointment_to_claim({
                                                                                    'appointment' => single_appointment
                                                                                  })
      expect(appt_with_claim['travelPayClaim']['metadata']['status']).to equal(520)
      expect(appt_with_claim['travelPayClaim']['metadata']['success']).to be(false)
      expect(appt_with_claim['travelPayClaim']['metadata']['message']).to include(/Uninitialized constant/i)
    end

    it 'returns 400 with error message if dates are invalid' do
      association_service = TravelPay::ClaimAssociationService.new(user, 'vagov')
      appt = association_service.associate_single_appointment_to_claim({
                                                                         'appointment' => single_appt_invalid
                                                                       })
      expect(appt['travelPayClaim']['metadata']['status']).to equal(400)
      expect(appt['travelPayClaim']['metadata']['success']).to be(false)
    end
  end
end
