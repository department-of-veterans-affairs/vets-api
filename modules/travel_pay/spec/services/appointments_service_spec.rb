# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::AppointmentsService do
  context 'get_appointment_by_date_time' do
    let(:user) { build(:user) }
    let(:appointments_data) do
      {
        'data' => [
          {
            'id' => 'uuid1',
            'appointmentSource' => 'API',
            'appointmentDateTime' => '2024-01-01T16:45:34.465Z',
            'appointmentName' => 'string',
            'appointmentType' => 'EnvironmentalHealth',
            'facilityName' => 'Cheyenne VA Medical Center',
            'serviceConnectedDisability' => 30,
            'currentStatus' => 'string',
            'appointmentStatus' => 'Completed',
            'externalAppointmentId' => '12345678-0000-0000-0000-000000000001',
            'associatedClaimId' => nil,
            'associatedClaimNumber' => nil,
            'isCompleted' => true
          },
          {
            'id' => 'uuid2',
            'appointmentSource' => 'API',
            'appointmentDateTime' => '2024-03-01T16:45:34.465Z',
            'appointmentName' => 'string',
            'appointmentType' => 'EnvironmentalHealth',
            'facilityName' => 'Cheyenne VA Medical Center',
            'serviceConnectedDisability' => 30,
            'currentStatus' => 'string',
            'appointmentStatus' => 'Completed',
            'externalAppointmentId' => '12345678-0000-0000-0000-000000000002',
            'associatedClaimId' => nil,
            'associatedClaimNumber' => nil,
            'isCompleted' => true
          },
          {
            'id' => 'uuid3',
            'appointmentSource' => 'API',
            'appointmentDateTime' => '2024-01-01T12:45:34.465Z',
            'appointmentName' => 'string',
            'appointmentType' => 'EnvironmentalHealth',
            'facilityName' => 'Cheyenne VA Medical Center',
            'serviceConnectedDisability' => 30,
            'currentStatus' => 'string',
            'appointmentStatus' => 'Completed',
            'externalAppointmentId' => '12345678-0000-0000-0000-000000000003',
            'associatedClaimId' => nil,
            'associatedClaimNumber' => nil,
            'isCompleted' => true
          },
          {
            'id' => 'uuid4',
            'appointmentSource' => 'API',
            'appointmentDateTime' => nil,
            'appointmentName' => 'string',
            'appointmentType' => 'EnvironmentalHealth',
            'facilityName' => 'Cheyenne VA Medical Center',
            'serviceConnectedDisability' => 30,
            'currentStatus' => 'string',
            'appointmentStatus' => 'Completed',
            'externalAppointmentId' => '12345678-0000-0000-0000-000000000004',
            'associatedClaimId' => nil,
            'associatedClaimNumber' => nil,
            'isCompleted' => true
          }
        ]
      }
    end
    let(:appointments_response) do
      Faraday::Response.new(
        body: appointments_data
      )
    end

    let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

    before do
      allow_any_instance_of(TravelPay::AppointmentsClient)
        .to receive(:get_all_appointments)
        .with(tokens[:veis_token], tokens[:btsss_token], { 'excludeWithClaims' => true })
        .and_return(appointments_response)

      auth_manager = object_double(TravelPay::AuthManager.new(123, user), authorize: tokens)
      @service = TravelPay::AppointmentsService.new(auth_manager)
    end

    context 'find by appt date-time' do
      it 'returns the BTSSS appointment that matches appt date' do
        date_string = '2024-01-01T12:45:34.465Z'
        appt = @service.get_appointment_by_date_time({ 'appt_datetime' => date_string })

        expect(appt[:data]['appointmentDateTime']).to eq(date_string)
      end

      it 'returns nil if appt date does not match' do
        appt = @service.get_appointment_by_date_time({ 'appt_datetime' => '1700-01-01T12:45:34.465Z' })

        expect(appt[:data]).to equal(nil)
      end

      it 'throws an Argument Error if appt date is invalid' do
        expect { @service.get_appointment_by_date_time({ 'appt_datetime' => 'banana' }) }
          .to raise_error(ArgumentError, /Invalid appointment time/i)

        expect { @service.get_appointment_by_date_time({ 'appt_datetime' => nil }) }
          .to raise_error(ArgumentError, /Invalid appointment time/i)
      end
    end
  end

  context 'find or create appointment' do
    let(:user) { build(:user) }

    let(:add_appointment_response) do
      Faraday::Response.new(
        body: {
          'data' => [
            {
              'id' => 'uuid1',
              'appointmentSource' => 'API',
              'appointmentDateTime' => '2024-01-01T16:45:34.465Z',
              'appointmentName' => 'string',
              'appointmentType' => 'EnvironmentalHealth',
              'facilityName' => 'Cheyenne VA Medical Center',
              'serviceConnectedDisability' => 30,
              'currentStatus' => 'string',
              'appointmentStatus' => 'Completed',
              'externalAppointmentId' => '12345678-0000-0000-0000-000000000001',
              'associatedClaimId' => nil,
              'associatedClaimNumber' => nil,
              'isCompleted' => true
            }
          ]
        }
      )
    end

    let(:tokens) { { veis_token: 'veis_token', btsss_token: 'btsss_token' } }

    before do
      allow_any_instance_of(TravelPay::AppointmentsClient)
        .to receive(:find_or_create)
        .with(tokens[:veis_token], tokens[:btsss_token],
              { 'appointment_date_time' => '2024-01-01 12:45:34 UTC',
                'facility_station_number' => '123',
                'appointment_name' => '',
                'appointment_type' => 'Other',
                'is_complete' => false })
        .and_return(add_appointment_response)

      auth_manager = object_double(TravelPay::AuthManager.new(123, user), authorize: tokens)
      @service = TravelPay::AppointmentsService.new(auth_manager)
    end

    it 'returns the BTSSS appointment that matches appt date' do
      date_string = '2024-01-01T12:45:34.465Z'

      params = { 'appointment_date_time' => date_string,
                 'facility_station_number' => '123',
                 'appointment_name' => '',
                 'appointment_type' => 'Other',
                 'is_complete' => false }

      appt = @service.find_or_create_appointment(params)

      expect(appt[:data]['id']).to eq('uuid1')
    end

    it 'throws an Argument Error if appt date is invalid' do
      expect do
        @service.find_or_create_appointment({ 'appointment_date_time' => 'banana',
                                              'facility_station_number' => '123',
                                              'appointment_name' => '',
                                              'appointment_type' => 'Other',
                                              'is_complete' => false })
      end
        .to raise_error(ArgumentError, /Invalid appointment time/i)

      expect do
        @service.find_or_create_appointment({ 'appointment_date_time' => nil,
                                              'facility_station_number' => '123',
                                              'appointment_name' => '',
                                              'appointment_type' => 'Other',
                                              'is_complete' => false })
      end
        .to raise_error(ArgumentError, /Invalid appointment time/i)
    end
  end
end
