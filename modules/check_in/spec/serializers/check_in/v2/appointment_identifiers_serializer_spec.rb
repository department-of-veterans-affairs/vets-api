# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::V2::AppointmentIdentifiersSerializer do
  subject { described_class }

  let(:appointment_data) do
    {
      uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
      options: {
        validStart: 'validStartDateTime',
        validEnd: 'validEndDateTime',
        additionalValidation: {
          lastName: 'veteranLastName',
          SSN4: 'veteranLastFour'
        }
      },
      payload: {
        'read.full': {
          appointments: [
            {
              appointmentIEN: '123',
              patientDFN: '888',
              stationNo: '5625',
              zipCode: 'appointment.zipCode',
              clinicName: 'appointment.clinicName',
              startTime: 'formattedStartTime',
              clinicPhoneNumber: 'appointment.clinicPhoneNumber',
              clinicFriendlyName: 'appointment.patientFriendlyName',
              facility: 'appointment.facility',
              facilityId: 'some-id',
              appointmentCheckInStart: 'time checkin starts',
              appointmentCheckInEnds: 'time checkin Ends',
              status: 'the status',
              timeCheckedIn: 'time the user checked already'
            },
            {
              appointmentIEN: '456',
              patientDFN: '888',
              stationNo: '5625',
              zipCode: 'appointment.zipCode',
              clinicName: 'appointment.clinicName',
              startTime: 'formattedStartTime',
              clinicPhoneNumber: 'appointment.clinicPhoneNumber',
              clinicFriendlyName: 'appointment.patientFriendlyName',
              facility: 'appointment.facility',
              facilityId: 'some-id',
              appointmentCheckInStart: 'time checkin starts',
              appointmentCheckInEnds: 'time checkin Ends',
              status: 'the status',
              timeCheckedIn: 'time the user checked already'
            }
          ]
        }
      }
    }
  end

  describe '#serializable_hash' do
    let(:serialized_hash_response) do
      {
        data: {
          id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
          type: :appointment_identifier,
          attributes: {
            patientDFN: '888',
            stationNo: '5625'
          }
        }
      }
    end

    it 'returns a serialized hash' do
      appt_struct = OpenStruct.new(appointment_data)
      appt_serializer = CheckIn::V2::AppointmentIdentifiersSerializer.new(appt_struct)

      expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
    end
  end
end
