# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::VAOS::AppointmentSerializer do
  subject { described_class }

  let(:vaos_appointment_data) do
    '{
      "data": [
        {
          "id": "180766",
          "identifier": [
            {
              "system": "Appointment/",
              "value": "413938333130383736"
            }
          ],
          "kind": "clinic",
          "status": "booked",
          "serviceType": "amputation",
          "patientIcn": "1013125218V696863",
          "locationId": "983GC",
          "clinic": "1081",
          "start": "2023-11-13T16:00:00Z",
          "end": "2023-11-13T16:30:00Z",
          "minutesDuration": 30,
          "facility": {
            "name": "abc facility",
            "vistaSite": "534",
            "timezone": { "timeZoneId": "America/New York" },
            "phone": { "main": "843-577-5011" }
          },
          "clinicInfo":{
            "data": {
              "serviceName": "CHS NEUROSURGERY VARMA",
              "physicalLocation": "1ST FL SPECIALTY MODULE 2",
              "friendlyName": "CHS NEUROSURGERY VARMA"
            }
          }
        },
        {
          "id": "180770",
          "identifier": [
            {
              "system": "Appointment/",
              "value": "413938333130383736"
            }
          ],
          "kind": "clinic",
          "status": "booked",
          "serviceType": "amputation",
          "patientIcn": "1013125218V696863",
          "locationId": "983GC",
          "clinic": "1081",
          "start": "2023-11-13T16:00:00Z",
          "end": "2023-11-13T16:30:00Z",
          "minutesDuration": 30,
          "facility": {
            "name": "def facility",
            "vistaSite": "909",
            "timezone": { "timeZoneId": "America/New York" },
            "phone": { "main": "843-577-5011" }
          },
          "clinicInfo":{
            "data": {
              "serviceName": "CaregiverSupport",
              "physicalLocation": "2360 East Pershing Boulevard",
              "friendlyName": "CaregiverSupport"
            }
          }
         }
       ]
    }'
  end
  let(:appt_struct_data) do
    struct = JSON.parse(vaos_appointment_data, object_class: OpenStruct)
    struct.data
  end
  let(:appointment1) do
    {
      id: '180766',
      type: :appointments,
      attributes: {
        kind: 'clinic',
        status: 'booked',
        serviceType: 'amputation',
        locationId: '983GC',
        clinic: '1081',
        start: '2023-11-13T16:00:00Z',
        end: '2023-11-13T16:30:00Z',
        minutesDuration: 30,
        facilityName: 'abc facility',
        facilityVistaSite: '534',
        facilityTimezone: 'America/New York',
        facilityPhoneMain: '843-577-5011',
        clinicServiceName: 'CHS NEUROSURGERY VARMA',
        clinicPhysicalLocation: '1ST FL SPECIALTY MODULE 2',
        clinicFriendlyName: 'CHS NEUROSURGERY VARMA'
      }
    }
  end
  let(:appointment2) do
    {
      id: '180770',
      type: :appointments,
      attributes: {
        kind: 'clinic',
        status: 'booked',
        serviceType: 'amputation',
        locationId: '983GC',
        clinic: '1081',
        start: '2023-11-13T16:00:00Z',
        end: '2023-11-13T16:30:00Z',
        minutesDuration: 30,
        facilityName: 'def facility',
        facilityVistaSite: '909',
        facilityTimezone: 'America/New York',
        facilityPhoneMain: '843-577-5011',
        clinicServiceName: 'CaregiverSupport',
        clinicPhysicalLocation: '2360 East Pershing Boulevard',
        clinicFriendlyName: 'CaregiverSupport'
      }
    }
  end

  context 'for valid vaos appointment data' do
    let(:serialized_hash_response) do
      {
        data: [appointment1, appointment2]
      }
    end

    it 'returns a serialized hash' do
      serializer = subject.new(appt_struct_data)
      expect(serializer.serializable_hash).to eq(serialized_hash_response)
    end
  end
end
