# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::AppointmentsService do
  context 'get_appointments_by_date' do
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
            'appointmentDateTime' => '2024-02-01T16:45:34.465Z',
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
            'appointmentDateTime' => '2024-02-11T16:45:34.465Z',
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

    context 'filter by appt date' do
      it 'returns appointments that match appt date if specified' do
        service = TravelPay::AppointmentsService.new
        appts = service.get_appointments_by_date(*tokens, { 'appt_datetime' => '2024-01-01' })

        expect(appts.count).to equal(1)
      end

      it 'returns 0 appointments if appt date does not match' do
        service = TravelPay::AppointmentsService.new
        appts = service.get_appointments_by_date(*tokens, { 'appt_datetime' => '1700-01-01' })

        expect(appts[:data].count).to equal(0)
      end

      it 'returns 0 appointments if appt date is invalid' do
        service = TravelPay::AppointmentsService.new
        appts = service.get_appointments_by_date(*tokens, { 'appt_datetime' => 'banana' })
        appts_empty_date = service.get_appointments_by_date(*tokens, { 'appt_datetime' => '' })

        expect(appts[:data].count).to equal(0)
        expect(appts_empty_date[:data].count).to equal(0)
      end
    end
  end
end
