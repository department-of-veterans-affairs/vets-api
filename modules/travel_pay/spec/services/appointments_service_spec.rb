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

    let(:tokens) { %w[veis_token btsss_token] }

    before do
      allow_any_instance_of(TravelPay::AppointmentsClient)
        .to receive(:get_all_appointments)
        .with(*tokens, { 'excludeWithClaims' => true })
        .and_return(appointments_response)
    end

    context 'find by appt date-time' do
      it 'returns the BTSSS appointment that matches appt date' do
        date_string = '2024-01-01T12:45:34.465Z'
        service = TravelPay::AppointmentsService.new
        appt = service.get_appointment_by_date_time(*tokens, { 'appt_datetime' => date_string })

        expect(appt[:data]['appointmentDateTime']).to eq(date_string)
      end

      it 'returns nil if appt date does not match' do
        service = TravelPay::AppointmentsService.new
        appt = service.get_appointment_by_date_time(*tokens, { 'appt_datetime' => '1700-01-01T12:45:34.465Z' })

        expect(appt[:data]).to equal(nil)
      end

      it 'throws an Argument Error if appt date is invalid' do
        service = TravelPay::AppointmentsService.new
        expect { service.get_appointment_by_date_time(*tokens, { 'appt_datetime' => 'banana' }) }
          .to raise_error(ArgumentError, /Invalid appointment time/i)

        expect { service.get_appointment_by_date_time(*tokens, { 'appt_datetime' => nil }) }
          .to raise_error(ArgumentError, /Invalid appointment time/i)
      end
    end
  end
end
