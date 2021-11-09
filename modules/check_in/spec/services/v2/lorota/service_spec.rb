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
            name: '',
            relationship: nil,
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
              zip4: '',
              country: ''
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
            'appointmentIEN' => '1',
            'zipCode' => 'appointment.zipCode',
            'clinicName' => 'appointment.clinicName',
            'startTime' => '2021-08-19T10:00:00',
            'clinicPhoneNumber' => 'appointment.clinicPhoneNumber',
            'clinicFriendlyName' => 'appointment.patientFriendlyName',
            'facility' => 'appointment.facility',
            'facilityId' => 'some-id',
            'appointmentCheckInStart' => '2021-08-19T09:030:00',
            'appointmentCheckInEnds' => 'time checkin Ends',
            'status' => 'the status',
            'timeCheckedIn' => 'time the user checked already'
          },
          {
            'appointmentIEN' => '2',
            'zipCode' => 'appointment.zipCode',
            'clinicName' => 'appointment.clinicName',
            'startTime' => '2021-08-19T15:00:00',
            'clinicPhoneNumber' => 'appointment.clinicPhoneNumber',
            'clinicFriendlyName' => 'appointment.patientFriendlyName',
            'facility' => 'appointment.facility',
            'facilityId' => 'some-id',
            'appointmentCheckInStart' => '2021-08-19T14:30:00',
            'appointmentCheckInEnds' => 'time checkin Ends',
            'status' => 'the status',
            'timeCheckedIn' => 'time the user checked already'
          }
        ]
      },
      id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d'
    }
  end

  before do
    allow(Flipper).to receive(:enabled?).with(:check_in_experience_demographics_page_enabled).and_return(true)
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
    let(:next_of_kin_data) do
      {
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
            }
          }
        }
      }
    end
    let(:response_with_next_of_kin) do
      approved_response.deep_merge(next_of_kin_data)
    end

    before do
      allow_any_instance_of(::V2::Lorota::RedisClient).to receive(:get).and_return('123abc')
      allow_any_instance_of(::V2::Lorota::Client).to receive(:data)
        .and_return(Faraday::Response.new(body: appointment_data.to_json, status: 200))
    end

    context 'with next of kin flag turned off' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:check_in_experience_next_of_kin_enabled).and_return(false)
      end

      it 'returns approved data without next of kin' do
        expect(subject.build(check_in: valid_check_in).check_in_data).to eq(approved_response)
      end
    end

    context 'with next of kin flag turned on' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:check_in_experience_next_of_kin_enabled).and_return(true)
      end

      it 'returns approved data with next of kin' do
        expect(subject.build(check_in: valid_check_in).check_in_data).to eq(response_with_next_of_kin)
      end
    end
  end
end
