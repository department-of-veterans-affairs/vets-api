# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::V2::AppointmentDataSerializer do
  subject { described_class }

  let(:appointment_data) do
    {
      id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
      scope: 'read.full',
      payload: {
        appointments: [
          {
            appointmentIEN: '1',
            patientDFN: '888',
            stationNo: '5625',
            zipCode: 'appointment.zipCode',
            clinicName: 'appointment.clinicName',
            startTime: '2021-08-19T10:00:00',
            clinicPhoneNumber: 'appointment.clinicPhoneNumber',
            clinicFriendlyName: 'appointment.patientFriendlyName',
            facility: 'appointment.facility',
            facilityId: 'some-id',
            appointmentCheckInStart: '2021-08-19T09:030:00',
            appointmentCheckInEnds: 'time checkin Ends',
            status: 'the status',
            timeCheckedIn: 'time the user checked already'
          },
          {
            appointmentIEN: '2',
            patientDFN: '888',
            stationNo: '5625',
            zipCode: 'appointment.zipCode',
            clinicName: 'appointment.clinicName',
            startTime: '2021-08-19T15:00:00',
            clinicPhoneNumber: 'appointment.clinicPhoneNumber',
            clinicFriendlyName: 'appointment.patientFriendlyName',
            facility: 'appointment.facility',
            facilityId: 'some-id',
            appointmentCheckInStart: '2021-08-19T14:30:00',
            appointmentCheckInEnds: 'time checkin Ends',
            status: 'the status',
            timeCheckedIn: 'time the user checked already'
          }
        ]
      }
    }
  end

  describe '#serializable_hash' do
    let(:serialized_hash_response) do
      {
        data: {
          id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
          type: :appointment_data,
          attributes: {
            payload: {
              appointments: [
                {
                  appointmentIEN: '1',
                  zipCode: 'appointment.zipCode',
                  clinicName: 'appointment.clinicName',
                  startTime: '2021-08-19T10:00:00',
                  clinicPhoneNumber: 'appointment.clinicPhoneNumber',
                  clinicFriendlyName: 'appointment.patientFriendlyName',
                  facility: 'appointment.facility',
                  facilityId: 'some-id',
                  appointmentCheckInStart: '2021-08-19T09:030:00',
                  appointmentCheckInEnds: 'time checkin Ends',
                  status: 'the status',
                  timeCheckedIn: 'time the user checked already'
                },
                {
                  appointmentIEN: '2',
                  zipCode: 'appointment.zipCode',
                  clinicName: 'appointment.clinicName',
                  startTime: '2021-08-19T15:00:00',
                  clinicPhoneNumber: 'appointment.clinicPhoneNumber',
                  clinicFriendlyName: 'appointment.patientFriendlyName',
                  facility: 'appointment.facility',
                  facilityId: 'some-id',
                  appointmentCheckInStart: '2021-08-19T14:30:00',
                  appointmentCheckInEnds: 'time checkin Ends',
                  status: 'the status',
                  timeCheckedIn: 'time the user checked already'
                }
              ]
            }
          }
        }
      }
    end

    it 'returns a serialized hash' do
      appt_struct = OpenStruct.new(appointment_data)
      appt_serializer = CheckIn::V2::AppointmentDataSerializer.new(appt_struct)

      expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
    end
  end
end
