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

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.build(check_in: valid_check_in)).to be_an_instance_of(V2::Lorota::Service)
    end
  end

  describe '#token_with_permissions' do
    it 'returns data from lorota' do
      allow_any_instance_of(V2::Lorota::Session).to receive(:from_lorota).and_return('abc123')

      hsh = {
        permission_data: {
          permissions: 'read.full',
          uuid: id,
          status: 'success'
        },
        jwt: 'abc123'
      }

      expect(subject.build(check_in: valid_check_in).token_with_permissions).to eq(hsh)
    end
  end

  describe '#get_check_in_data' do
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
    let(:approved_response) do
      {
        id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
        payload: {
          appointments: [
            {
              'appointmentIEN' => '123',
              'zipCode' => 'appointment.zipCode',
              'clinicName' => 'appointment.clinicName',
              'startTime' => 'formattedStartTime',
              'clinicPhoneNumber' => 'appointment.clinicPhoneNumber',
              'clinicFriendlyName' => 'appointment.patientFriendlyName',
              'facility' => 'appointment.facility',
              'facilityId' => 'some-id',
              'appointmentCheckInStart' => 'time checkin starts',
              'appointmentCheckInEnds' => 'time checkin Ends',
              'status' => 'the status',
              'timeCheckedIn' => 'time the user checked already'
            },
            {
              'appointmentIEN' => '456',
              'zipCode' => 'appointment.zipCode',
              'clinicName' => 'appointment.clinicName',
              'startTime' => 'formattedStartTime',
              'clinicPhoneNumber' => 'appointment.clinicPhoneNumber',
              'clinicFriendlyName' => 'appointment.patientFriendlyName',
              'facility' => 'appointment.facility',
              'facilityId' => 'some-id',
              'appointmentCheckInStart' => 'time checkin starts',
              'appointmentCheckInEnds' => 'time checkin Ends',
              'status' => 'the status',
              'timeCheckedIn' => 'time the user checked already'
            }
          ]
        }
      }
    end

    before do
      allow_any_instance_of(::V2::Lorota::Session).to receive(:from_redis).and_return('123abc')
      allow_any_instance_of(::V2::Lorota::Request).to receive(:get)
        .and_return(Faraday::Response.new(body: appointment_data.to_json, status: 200))
    end

    it 'returns approved data' do
      expect(subject.build(check_in: valid_check_in).get_check_in_data).to eq(approved_response)
    end
  end

  describe '#base_path' do
    it 'returns base_path' do
      expect(subject.build(check_in: valid_check_in).base_path).to eq('dev')
    end
  end
end
