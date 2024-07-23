# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::V2::AppointmentDataSerializer do
  subject { described_class }

  let(:appointment_data) do
    {
      id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
      scope: 'read.full',
      payload: {
        demographics: {
          nextOfKin1: {
            name: 'VETERAN,JONAH',
            relationship: 'BROTHER',
            phone: '1112223333',
            workPhone: '4445556666',
            address: {
              street1: '123 Main St',
              street2: 'Ste 234',
              street3: '',
              city: 'Los Angeles',
              county: 'Los Angeles',
              state: 'CA',
              zip: '90089',
              zip4: nil,
              country: 'USA'
            }
          },
          nextOfKin2: {
            name: '',
            relationship: '',
            phone: '',
            workPhone: '',
            address: {
              street1: '',
              street2: '',
              street3: '',
              city: '',
              county: nil,
              state: '',
              zip: '',
              zip4: nil,
              country: nil
            }
          },
          emergencyContact: {
            name: 'VETERAN,JONAH',
            relationship: 'BROTHER',
            phone: '1112223333',
            workPhone: '4445556666',
            address: {
              street1: '123 Main St',
              street2: 'Ste 234',
              street3: '',
              city: 'Los Angeles',
              county: 'Los Angeles',
              state: 'CA',
              zip: '90089',
              zip4: nil,
              country: 'USA'
            }
          },
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
            appointmentIEN: '460',
            checkedInTime: '',
            checkInSteps: {},
            checkInWindowEnd: '2021-12-23T08:40:00.000-05:00',
            checkInWindowStart: '2021-12-23T08:00:00.000-05:00',
            clinicCreditStopCodeName: 'SOCIAL WORK SERVICE',
            clinicFriendlyName: 'Health Wellness',
            clinicIen: 500,
            clinicLocation: 'ATLANTA VAMC',
            clinicName: 'Family Wellness',
            clinicPhoneNumber: '555-555-5555',
            clinicStopCodeName: 'PRIMARY CARE/MEDICINE',
            doctorName: '',
            eligibility: 'ELIGIBLE',
            facility: 'VEHU DIVISION',
            kind: 'clinic',
            patientDFN: '888',
            startTime: '2021-12-23T08:30:00',
            stationNo: 5625,
            status: ''
          },
          {
            appointmentIEN: '461',
            checkedInTime: '',
            checkInSteps: {},
            checkInWindowEnd: '2021-12-23T09:40:00.000-05:00',
            checkInWindowStart: '2021-12-23T09:00:00.000-05:00',
            clinicCreditStopCodeName: 'SOCIAL WORK SERVICE',
            clinicFriendlyName: 'CARDIOLOGY',
            clinicIen: 500,
            clinicLocation: 'ATLANTA VAMC',
            clinicName: 'CARDIOLOGY',
            clinicPhoneNumber: '555-555-5555',
            clinicStopCodeName: 'PRIMARY CARE/MEDICINE',
            doctorName: '',
            eligibility: 'ELIGIBLE',
            facility: 'CARDIO DIVISION',
            kind: 'phone',
            patientDFN: '888',
            startTime: '2021-12-23T09:30:00',
            stationNo: 5625,
            status: ''
          }
        ],
        patientDemographicsStatus: {
          demographicsNeedsUpdate: true,
          demographicsConfirmedAt: nil,
          nextOfKinNeedsUpdate: false,
          nextOfKinConfirmedAt: '2021-12-10T05:15:00.000-05:00',
          emergencyContactNeedsUpdate: true,
          emergencyContactConfirmedAt: '2021-12-10T05:30:00.000-05:00'
        }
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
              address: nil,
              demographics: {
                mailingAddress: {
                  street1: '123 Turtle Trail',
                  street2: '',
                  street3: '',
                  city: 'Treetopper',
                  county: 'SAN BERNARDINO',
                  state: 'Tennessee',
                  zip: '101010',
                  zip4: nil,
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
                  zip4: nil,
                  country: 'USA'
                },
                homePhone: '5552223333',
                mobilePhone: '5553334444',
                workPhone: '5554445555',
                emailAddress: 'kermit.frog@sesameenterprises.us',
                nextOfKin1: {
                  name: 'VETERAN,JONAH',
                  relationship: 'BROTHER',
                  phone: '1112223333',
                  workPhone: '4445556666',
                  address: {
                    street1: '123 Main St',
                    street2: 'Ste 234',
                    street3: '',
                    city: 'Los Angeles',
                    county: 'Los Angeles',
                    state: 'CA',
                    zip: '90089',
                    zip4: nil,
                    country: 'USA'
                  }
                },
                emergencyContact: {
                  name: 'VETERAN,JONAH',
                  relationship: 'BROTHER',
                  phone: '1112223333',
                  workPhone: '4445556666',
                  address: {
                    street1: '123 Main St',
                    street2: 'Ste 234',
                    street3: '',
                    city: 'Los Angeles',
                    county: 'Los Angeles',
                    state: 'CA',
                    zip: '90089',
                    zip4: nil,
                    country: 'USA'
                  }
                }
              },
              appointments: [
                {
                  appointmentIEN: '460',
                  checkedInTime: '',
                  checkInSteps: {},
                  checkInWindowEnd: '2021-12-23T08:40:00.000-05:00',
                  checkInWindowStart: '2021-12-23T08:00:00.000-05:00',
                  clinicCreditStopCodeName: 'SOCIAL WORK SERVICE',
                  clinicFriendlyName: 'Health Wellness',
                  clinicIen: 500,
                  clinicLocation: 'ATLANTA VAMC',
                  clinicName: 'Family Wellness',
                  clinicPhoneNumber: '555-555-5555',
                  clinicStopCodeName: 'PRIMARY CARE/MEDICINE',
                  doctorName: '',
                  eligibility: 'ELIGIBLE',
                  facility: 'VEHU DIVISION',
                  kind: 'clinic',
                  startTime: '2021-12-23T08:30:00',
                  stationNo: 5625,
                  status: ''
                },
                {
                  appointmentIEN: '461',
                  checkedInTime: '',
                  checkInSteps: {},
                  checkInWindowEnd: '2021-12-23T09:40:00.000-05:00',
                  checkInWindowStart: '2021-12-23T09:00:00.000-05:00',
                  clinicCreditStopCodeName: 'SOCIAL WORK SERVICE',
                  clinicFriendlyName: 'CARDIOLOGY',
                  clinicIen: 500,
                  clinicLocation: 'ATLANTA VAMC',
                  clinicName: 'CARDIOLOGY',
                  clinicPhoneNumber: '555-555-5555',
                  clinicStopCodeName: 'PRIMARY CARE/MEDICINE',
                  doctorName: '',
                  eligibility: 'ELIGIBLE',
                  facility: 'CARDIO DIVISION',
                  kind: 'phone',
                  startTime: '2021-12-23T09:30:00',
                  stationNo: 5625,
                  status: ''
                }
              ],
              patientDemographicsStatus: {
                demographicsNeedsUpdate: true,
                demographicsConfirmedAt: nil,
                nextOfKinNeedsUpdate: false,
                nextOfKinConfirmedAt: '2021-12-10T05:15:00.000-05:00',
                emergencyContactNeedsUpdate: true,
                emergencyContactConfirmedAt: '2021-12-10T05:30:00.000-05:00'
              },
              setECheckinStartedCalled: nil
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

    context 'when demographics and demographics status are nil' do
      let(:appointment_data) do
        {
          id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
          payload: {
            appointments: [
              {
                appointmentIEN: '460'
              }
            ]
          }
        }
      end
      let(:serialized_hash_response) do
        {
          data: {
            id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
            type: :appointment_data,
            attributes: {
              payload: {
                address: nil,
                demographics: {},
                appointments: [
                  {
                    appointmentIEN: '460'
                  }
                ],
                patientDemographicsStatus: {},
                setECheckinStartedCalled: nil
              }
            }
          }
        }
      end

      it 'return empty hash' do
        appt_struct = OpenStruct.new(appointment_data)
        appt_serializer = CheckIn::V2::AppointmentDataSerializer.new(appt_struct)

        expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
      end
    end

    context 'for OH data' do
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
      let(:serialized_hash_response) do
        {
          data: {
            id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
            type: :appointment_data,
            attributes: {
              payload: {
                address: '1166 6th Avenue 22, New York, NY 23423 US',
                demographics: {},
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
                    facility: 'Jerry L. Pettis Memorial Veterans Hospital',
                    facilityAddress: {
                      city: 'Loma Linda',
                      state: 'CA',
                      street1: '',
                      street2: '',
                      street3: '',
                      zip: '92357-1000'
                    },
                    kind: 'clinic',
                    startTime: '2024-02-14T22:10:00.000+00:00',
                    stationNo: '530',
                    status: 'Confirmed',
                    timezone: 'America/Los_Angeles'
                  }
                ],
                patientDemographicsStatus: {},
                setECheckinStartedCalled: nil
              }
            }
          }
        }
      end

      it 'returns a serialized hash' do
        appt_struct = OpenStruct.new(appointment_data_oh)
        appt_serializer = CheckIn::V2::AppointmentDataSerializer.new(appt_struct)

        expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
      end
    end
  end
end
