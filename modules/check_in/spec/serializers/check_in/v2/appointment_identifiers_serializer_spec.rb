# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::V2::AppointmentIdentifiersSerializer do
  subject { described_class }

  let(:appointment_data) do
    {
      id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
      scope: 'read.full',
      payload: {
        demographics: {
          mailingAddress: {
            street1: '123 Turtle Trail',
            street2: '',
            street3: '',
            city: 'Treetopper',
            county: 'SAN BERNARDINO',
            state: 'Tennessee',
            zip: '101010',
            country: 'USA'
          },
          homeAddress: {
            street1: '445 Fine Finch Fairway',
            street2: 'Apt 201',
            street3: '',
            city: 'Fairfence',
            county: 'FOO',
            state: 'Florida',
            zip: '445545',
            country: 'USA'
          },
          homePhone: '5552223333',
          patientCellPhone: '5553334444',
          workPhone: '5554445555',
          emailAddress: 'kermit.frog@sesameenterprises.us'
        },
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
    context 'when icn does not exist' do
      let(:serialized_hash_response) do
        {
          data: {
            id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
            type: :appointment_identifier,
            attributes: {
              patientDFN: '888',
              stationNo: '5625',
              icn: nil,
              patientCellPhone: '5553334444'
            }
          }
        }
      end

      it 'returns a serialized hash with icn nil' do
        appt_struct = OpenStruct.new(appointment_data)
        appt_serializer = CheckIn::V2::AppointmentIdentifiersSerializer.new(appt_struct)

        expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
      end
    end

    context 'when icn exists' do
      let(:appointment_data_icn) do
        appointment_data[:payload][:demographics].merge!(icn: '12340V123456')
        appointment_data
      end
      let(:serialized_hash_response) do
        {
          data: {
            id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
            type: :appointment_identifier,
            attributes: {
              patientDFN: '888',
              stationNo: '5625',
              icn: '12340V123456',
              patientCellPhone: '5553334444'
            }
          }
        }
      end

      it 'returns a serialized hash with icn' do
        appt_struct = OpenStruct.new(appointment_data_icn)
        appt_serializer = CheckIn::V2::AppointmentIdentifiersSerializer.new(appt_struct)

        expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
      end
    end

    context 'when patientCellPhone does not exist' do
      let(:appointment_data_without_mobile_phone) do
        appointment_data[:payload][:demographics].except!(:patientCellPhone)
        appointment_data
      end

      let(:serialized_hash_response) do
        {
          data: {
            id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
            type: :appointment_identifier,
            attributes: {
              patientDFN: '888',
              stationNo: '5625',
              icn: nil,
              patientCellPhone: nil
            }
          }
        }
      end

      it 'returns a serialized hash with patientCellPhone nil' do
        appt_struct = OpenStruct.new(appointment_data_without_mobile_phone)
        appt_serializer = CheckIn::V2::AppointmentIdentifiersSerializer.new(appt_struct)

        expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
      end
    end

    context 'when patientCellPhone exists' do
      let(:serialized_hash_response) do
        {
          data: {
            id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
            type: :appointment_identifier,
            attributes: {
              patientDFN: '888',
              stationNo: '5625',
              icn: nil,
              patientCellPhone: '5553334444'
            }
          }
        }
      end

      it 'returns a serialized hash with patientCellPhone' do
        appt_struct = OpenStruct.new(appointment_data)
        appt_serializer = CheckIn::V2::AppointmentIdentifiersSerializer.new(appt_struct)

        expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
      end
    end
  end
end
