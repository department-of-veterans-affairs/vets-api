# frozen_string_literal: true

require 'rails_helper'

describe V2::Lorota::Service do
  subject { described_class }

  let(:id) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:opts) do
    {
      data: {
        uuid: id,
        last4: '1234',
        last_name: 'Johnson'
      }
    }
  end
  let(:valid_check_in) { CheckIn::V2::Session.build(opts) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
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
  let(:approved_response) do
    {
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
            'appointmentIEN' => '460',
            'checkedInTime' => '',
            'checkInSteps' => {},
            'checkInWindowEnd' => '2021-12-23T08:40:00.000-05:00',
            'checkInWindowStart' => '2021-12-23T08:00:00.000-05:00',
            'clinicCreditStopCodeName' => 'SOCIAL WORK SERVICE',
            'clinicFriendlyName' => 'Health Wellness',
            'clinicIen' => 500,
            'clinicLocation' => 'ATLANTA VAMC',
            'clinicName' => 'Family Wellness',
            'clinicPhoneNumber' => '555-555-5555',
            'clinicStopCodeName' => 'PRIMARY CARE/MEDICINE',
            'doctorName' => '',
            'eligibility' => 'ELIGIBLE',
            'facility' => 'VEHU DIVISION',
            'kind' => 'clinic',
            'startTime' => '2021-12-23T08:30:00',
            'stationNo' => 5625,
            'status' => ''
          },
          {
            'appointmentIEN' => '461',
            'checkedInTime' => '',
            'checkInSteps' => {},
            'checkInWindowEnd' => '2021-12-23T09:40:00.000-05:00',
            'checkInWindowStart' => '2021-12-23T09:00:00.000-05:00',
            'clinicCreditStopCodeName' => 'SOCIAL WORK SERVICE',
            'clinicFriendlyName' => 'CARDIOLOGY',
            'clinicIen' => 500,
            'clinicLocation' => 'ATLANTA VAMC',
            'clinicName' => 'CARDIOLOGY',
            'clinicPhoneNumber' => '555-555-5555',
            'clinicStopCodeName' => 'PRIMARY CARE/MEDICINE',
            'doctorName' => '',
            'eligibility' => 'ELIGIBLE',
            'facility' => 'CARDIO DIVISION',
            'kind' => 'phone',
            'startTime' => '2021-12-23T09:30:00',
            'stationNo' => 5625,
            'status' => ''
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
      },
      id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d'
    }
  end

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.build(check_in: valid_check_in)).to be_an_instance_of(V2::Lorota::Service)
    end
  end

  describe '#token' do
    let(:token) { 'abc123' }
    let(:token_response) do
      {
        permission_data: {
          permissions: 'read.full',
          uuid: id,
          status: 'success'
        },
        jwt: token
      }
    end

    before do
      allow_any_instance_of(V2::Lorota::Client).to receive(:token)
        .and_return(Faraday::Response.new(body: { token: token }.to_json, status: 200))
    end

    it 'returns data from lorota' do
      expect(subject.build(check_in: valid_check_in).token).to eq(token_response)
    end
  end

  describe '#check_in_data' do
    before do
      allow_any_instance_of(::V2::Lorota::RedisClient).to receive(:get).and_return('123abc')
      allow_any_instance_of(::V2::Lorota::Client).to receive(:data)
        .and_return(Faraday::Response.new(body: appointment_data.to_json, status: 200))
    end

    context 'when check_in_type is preCheckIn' do
      let(:opts) { { data: { check_in_type: 'preCheckIn' } } }
      let(:pre_check_in) { CheckIn::V2::Session.build(opts) }

      it 'does not save appointment identifiers' do
        expect_any_instance_of(CheckIn::V2::PatientCheckIn).not_to receive(:save)

        subject.build(check_in: pre_check_in).check_in_data
      end
    end

    context 'when check_in_type is not preCheckIn' do
      let(:opts) { { data: { check_in_type: 'anything else' } } }
      let(:check_in) { CheckIn::V2::Session.build(opts) }

      it 'saves appointment identifiers' do
        expect_any_instance_of(CheckIn::V2::PatientCheckIn).to receive(:save).once

        subject.build(check_in: check_in).check_in_data
      end
    end

    it 'returns approved data' do
      expect(subject.build(check_in: valid_check_in).check_in_data).to eq(approved_response)
    end
  end
end
