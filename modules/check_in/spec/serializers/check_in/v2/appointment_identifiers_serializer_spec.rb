# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::V2::AppointmentIdentifiersSerializer do
  subject { described_class }

  let(:appointment_data) do
    {
      id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
      scope: 'read.full',
      payload: {
        patientCellPhone: '4445556666',
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
          mobilePhone: '5553334444',
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

  let(:appointment_data_oh) do
    {
      id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
      scope: 'read.full',
      payload: {
        address: '1166 6th Avenue 22, New York, NY 23423 US',
        appointments: [
          {
            appointmentIEN: '4822366',
            clinicCreditStopCodeName: '',
            clinicFriendlyName: 'Endoscopy',
            clinicIen: '32216049',
            clinicLocation: '',
            clinicName: 'Endoscopy',
            clinicPhoneNumber: '909-825-7084',
            clinicStopCodeName: 'Mental Health, Primary Care',
            doctorName: 'Dr. Jones',
            edipi: '1000000105',
            facility: 'Jerry L. Pettis Memorial Veterans Hospital',
            facilityAddress: {
              city: 'Loma Linda',
              state: 'CA',
              street1: '',
              street2: '',
              street3: '',
              zip: '92357-1000'
            },
            icn: '1013220078V743173',
            kind: 'clinic',
            startTime: '2024-02-14T22:10:00.000+00:00',
            stationNo: '530',
            status: 'Confirmed',
            timezone: 'America/Los_Angeles'
          }
        ],
        patientCellPhone: '4445556666',
        facilityType: 'OH'
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
              appointmentIEN: '1',
              icn: nil,
              mobilePhone: '5553334444',
              patientCellPhone: '4445556666',
              facilityType: nil,
              edipi: nil
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
              appointmentIEN: '1',
              icn: '12340V123456',
              mobilePhone: '5553334444',
              patientCellPhone: '4445556666',
              facilityType: nil,
              edipi: nil
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

    context 'when mobilePhone does not exist' do
      let(:appointment_data_without_mobile_phone) do
        appointment_data[:payload][:demographics].except!(:mobilePhone)
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
              appointmentIEN: '1',
              icn: nil,
              mobilePhone: nil,
              patientCellPhone: '4445556666',
              facilityType: nil,
              edipi: nil
            }
          }
        }
      end

      it 'returns a serialized hash with mobilePhone nil' do
        appt_struct = OpenStruct.new(appointment_data_without_mobile_phone)
        appt_serializer = CheckIn::V2::AppointmentIdentifiersSerializer.new(appt_struct)

        expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
      end
    end

    context 'when mobilePhone exists' do
      let(:serialized_hash_response) do
        {
          data: {
            id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
            type: :appointment_identifier,
            attributes: {
              patientDFN: '888',
              stationNo: '5625',
              appointmentIEN: '1',
              icn: nil,
              mobilePhone: '5553334444',
              patientCellPhone: '4445556666',
              facilityType: nil,
              edipi: nil
            }
          }
        }
      end

      it 'returns a serialized hash with mobilePhone' do
        appt_struct = OpenStruct.new(appointment_data)
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
              appointmentIEN: '1',
              icn: nil,
              mobilePhone: '5553334444',
              patientCellPhone: '4445556666',
              facilityType: nil,
              edipi: nil
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

    context 'when patientCellPhone does not exist' do
      let(:appointment_data_without_patient_cell_phone) do
        appointment_data[:payload].except!(:patientCellPhone)
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
              appointmentIEN: '1',
              icn: nil,
              mobilePhone: '5553334444',
              patientCellPhone: nil,
              facilityType: nil,
              edipi: nil
            }
          }
        }
      end

      it 'returns a serialized hash without patientCellPhone' do
        appt_struct = OpenStruct.new(appointment_data_without_patient_cell_phone)
        appt_serializer = CheckIn::V2::AppointmentIdentifiersSerializer.new(appt_struct)

        expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
      end
    end

    context 'when appointmentIEN exists' do
      let(:serialized_hash_response) do
        {
          data: {
            id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
            type: :appointment_identifier,
            attributes: {
              patientDFN: '888',
              stationNo: '5625',
              appointmentIEN: '1',
              icn: nil,
              mobilePhone: '5553334444',
              patientCellPhone: '4445556666',
              facilityType: nil,
              edipi: nil
            }
          }
        }
      end

      it 'returns a serialized hash with appointmentIEN' do
        appt_struct = OpenStruct.new(appointment_data)
        appt_serializer = CheckIn::V2::AppointmentIdentifiersSerializer.new(appt_struct)

        expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
      end
    end

    context 'when appointmentIEN does not exist' do
      let(:appointment_data_without_appointment_ien) do
        appointment_data[:payload][:appointments][0].except!(:appointmentIEN)
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
              appointmentIEN: nil,
              icn: nil,
              mobilePhone: '5553334444',
              patientCellPhone: '4445556666',
              facilityType: nil,
              edipi: nil
            }
          }
        }
      end

      it 'returns a serialized hash without appointmentIEN' do
        appt_struct = OpenStruct.new(appointment_data_without_appointment_ien)
        appt_serializer = CheckIn::V2::AppointmentIdentifiersSerializer.new(appt_struct)

        expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
      end
    end

    context 'when facility type and edipi exists' do
      let(:appointment_data_edipi) do
        appointment_data[:payload].merge!(facilityType: 'OH')
        appointment_data[:payload][:appointments][0].merge!(edipi: '1000000105')
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
              appointmentIEN: '1',
              icn: nil,
              mobilePhone: '5553334444',
              patientCellPhone: '4445556666',
              facilityType: 'OH',
              edipi: '1000000105'
            }
          }
        }
      end

      it 'returns a serialized hash with edipi and facility type' do
        appt_struct = OpenStruct.new(appointment_data_edipi)
        appt_serializer = CheckIn::V2::AppointmentIdentifiersSerializer.new(appt_struct)

        expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
      end
    end

    context 'for OH data' do
      let(:serialized_hash_response) do
        {
          data: {
            id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
            type: :appointment_identifier,
            attributes: {
              patientDFN: nil,
              stationNo: '530',
              appointmentIEN: '4822366',
              icn: '1013220078V743173',
              mobilePhone: nil,
              patientCellPhone: '4445556666',
              facilityType: 'OH',
              edipi: '1000000105'
            }
          }
        }
      end

      it 'returns serialized identifier data' do
        appt_struct = OpenStruct.new(appointment_data_oh)
        appt_serializer = CheckIn::V2::AppointmentIdentifiersSerializer.new(appt_struct)

        expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
      end
    end
  end
end
