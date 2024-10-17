# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::VAOS::AppointmentSerializer do
  subject { described_class }

  context 'for valid vaos clinic appointment data' do
    let(:vaos_clinic_appointment_data) do
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
      struct = JSON.parse(vaos_clinic_appointment_data, object_class: OpenStruct)
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
          telehealth: {
            vvsKind: nil,
            atlas: nil
          },
          extension: {
            preCheckinAllowed: nil,
            eCheckinAllowed: nil,
            patientHasMobileGfe: nil
          },
          serviceCategory: nil,
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
          telehealth: {
            vvsKind: nil,
            atlas: nil
          },
          extension: {
            preCheckinAllowed: nil,
            eCheckinAllowed: nil,
            patientHasMobileGfe: nil
          },
          serviceCategory: nil,
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

  context 'for valid vaos video appointment data at atlas location' do
    let(:vaos_video_appointment_data) do
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
            "kind": "telehealth",
            "status": "booked",
            "serviceType": "amputation",
            "patientIcn": "1013125218V696863",
            "locationId": "983GC",
            "clinic": "1081",
            "start": "2023-11-13T16:00:00Z",
            "end": "2023-11-13T16:30:00Z",
            "minutesDuration": 30,
            "telehealth": {
              "url": "https://dev.care2.va.gov/vvc-app/?join=1&media=1&escalate=1&userType=guest&conference=VAC000003896@dev.care2.va.gov&pin=104039&aid=5c21ee08-7bc9-4cc3-b557-0fc543c40148#",
              "atlas": {
                "siteCode": "VFW-DC-20011-02",
                "confirmationCode": "075041",
                "address": {
                  "streetAddress": "5929 Georgia Ave NW",
                  "city": "Washington",
                  "state": "DC",
                  "zipCode": "20011",
                  "country": "USA",
                  "latitutde": 38.961979,
                  "longitude": -77.027908,
                  "additionalDetails": ""
                }
              },
              "group": false,
              "vvsKind": "ADHOC"
            },
            "extension": {
              "ccLocation": {
                "address": {}
              },
              "vistaStatus": [
                "NO ACTION TAKEN"
              ],
              "preCheckinAllowed": true,
              "eCheckinAllowed": true,
              "clinic": {}
            },
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
          }
       ]
      }'
    end
    let(:video_appt_struct_data) do
      struct = JSON.parse(vaos_video_appointment_data, object_class: OpenStruct)
      struct.data
    end
    let(:atlas_struct_data) do
      address = OpenStruct.new(streetAddress: '5929 Georgia Ave NW', city: 'Washington', state: 'DC', zipCode: '20011',
                               country: 'USA', latitutde: 38.961979, longitude: -77.027908, additionalDetails: '')
      OpenStruct.new(siteCode: 'VFW-DC-20011-02', confirmationCode: '075041', address:)
    end
    let(:appointment1) do
      {
        id: '180766',
        type: :appointments,
        attributes: {
          kind: 'telehealth',
          status: 'booked',
          serviceType: 'amputation',
          locationId: '983GC',
          clinic: '1081',
          start: '2023-11-13T16:00:00Z',
          end: '2023-11-13T16:30:00Z',
          minutesDuration: 30,
          telehealth: {
            vvsKind: 'ADHOC',
            atlas: atlas_struct_data
          },
          extension: {
            preCheckinAllowed: true,
            eCheckinAllowed: true,
            patientHasMobileGfe: nil
          },
          serviceCategory: nil,
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

    let(:serialized_hash_response) do
      {
        data: [appointment1]
      }
    end

    it 'returns a serialized hash' do
      serializer = subject.new(video_appt_struct_data)
      expect(serializer.serializable_hash).to eq(serialized_hash_response)
    end
  end

  context 'for valid vaos video appointment data at home' do
    let(:vaos_video_appointment_data) do
      '{
        "data": [
          {
            "id": "180770",
            "identifier": [
              {
                "system": "Appointment/",
                "value": "413938333130383736"
              }
            ],
            "kind": "telehealth",
            "status": "booked",
            "serviceType": "amputation",
            "patientIcn": "1013125218V696863",
            "locationId": "983GC",
            "clinic": "1081",
            "start": "2023-11-13T16:00:00Z",
            "end": "2023-11-13T16:30:00Z",
            "minutesDuration": 30,
            "telehealth": {
              "url": "https://pexip.mapsandbox.net/vvc-app/?join=1&media=1&escalate=1&userType=guest&conference=VAC000056916@pexip.mapsandbox.net&pin=351792&aid=0703f6b2-a033-489a-bf54-1162e6f3019d#",
              "group": true,
              "vvsKind": "ADHOC"
            },
            "extension": {
              "ccLocation": {
              "address": {}
              },
              "vistaStatus": [],
              "patientHasMobileGfe": false
            },
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
    let(:video_appt_struct_data) do
      struct = JSON.parse(vaos_video_appointment_data, object_class: OpenStruct)
      struct.data
    end
    let(:atlas_struct_data) do
      address = OpenStruct.new(streetAddress: '5929 Georgia Ave NW', city: 'Washington', state: 'DC', zipCode: '20011',
                               country: 'USA', latitutde: 38.961979, longitude: -77.027908, additionalDetails: '')
      OpenStruct.new(siteCode: 'VFW-DC-20011-02', confirmationCode: '075041', address:)
    end
    let(:appointment1) do
      {
        id: '180770',
        type: :appointments,
        attributes: {
          kind: 'telehealth',
          status: 'booked',
          serviceType: 'amputation',
          locationId: '983GC',
          clinic: '1081',
          start: '2023-11-13T16:00:00Z',
          end: '2023-11-13T16:30:00Z',
          minutesDuration: 30,
          telehealth: {
            vvsKind: 'ADHOC',
            atlas: nil
          },
          extension: {
            preCheckinAllowed: nil,
            eCheckinAllowed: nil,
            patientHasMobileGfe: false
          },
          serviceCategory: nil,
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

    let(:serialized_hash_response) do
      {
        data: [appointment1]
      }
    end

    it 'returns a serialized hash' do
      serializer = subject.new(video_appt_struct_data)
      expect(serializer.serializable_hash).to eq(serialized_hash_response)
    end
  end

  context 'for valid vaos video appointment on GFE' do
    let(:vaos_video_appointment_data) do
      '{
        "data": [
        {
          "id": "180770",
          "identifier": [
            {
              "system": "Appointment/",
              "value": "413938333130383736"
            }
          ],
          "kind": "telehealth",
          "status": "booked",
          "serviceType": "amputation",
          "patientIcn": "1013125218V696863",
          "locationId": "983GC",
          "clinic": "1081",
          "start": "2023-11-13T16:00:00Z",
          "end": "2023-11-13T16:30:00Z",
          "minutesDuration": 30,
          "telehealth": {
            "url": "https://pexip.mapsandbox.net/vvc-app/?join=1&media=1&escalate=1&userType=guest&conference=VAC000056916@pexip.mapsandbox.net&pin=351792&aid=0703f6b2-a033-489a-bf54-1162e6f3019d#",
            "group": true,
            "vvsKind": "ADHOC"
          },
          "extension": {
            "ccLocation": {
            "address": {}
            },
            "vistaStatus": [],
            "patientHasMobileGfe": true
          },
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
    let(:video_appt_struct_data) do
      struct = JSON.parse(vaos_video_appointment_data, object_class: OpenStruct)
      struct.data
    end
    let(:atlas_struct_data) do
      address = OpenStruct.new(streetAddress: '5929 Georgia Ave NW', city: 'Washington', state: 'DC', zipCode: '20011',
                               country: 'USA', latitutde: 38.961979, longitude: -77.027908, additionalDetails: '')
      OpenStruct.new(siteCode: 'VFW-DC-20011-02', confirmationCode: '075041', address:)
    end

    let(:appointment1) do
      {
        id: '180770',
        type: :appointments,
        attributes: {
          kind: 'telehealth',
          status: 'booked',
          serviceType: 'amputation',
          locationId: '983GC',
          clinic: '1081',
          start: '2023-11-13T16:00:00Z',
          end: '2023-11-13T16:30:00Z',
          minutesDuration: 30,
          telehealth: {
            vvsKind: 'ADHOC',
            atlas: nil
          },
          extension: {
            preCheckinAllowed: nil,
            eCheckinAllowed: nil,
            patientHasMobileGfe: true
          },
          serviceCategory: nil,
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

    let(:serialized_hash_response) do
      {
        data: [appointment1]
      }
    end

    it 'returns a serialized hash' do
      serializer = subject.new(video_appt_struct_data)
      expect(serializer.serializable_hash).to eq(serialized_hash_response)
    end
  end

  context 'for valid vaos video appointment at VA location' do
    let(:vaos_video_appointment_data) do
      '{
        "data": [
          {
            "id": "180770",
            "identifier": [
              {
                "system": "Appointment/",
                "value": "413938333130383736"
              }
            ],
            "kind": "telehealth",
            "status": "booked",
            "serviceType": "amputation",
            "patientIcn": "1013125218V696863",
            "locationId": "983GC",
            "clinic": "1081",
            "start": "2023-11-13T16:00:00Z",
            "end": "2023-11-13T16:30:00Z",
            "minutesDuration": 30,
            "telehealth": {
              "url": "https://pexip.mapsandbox.net/vvc-app/?join=1&media=1&escalate=1&userType=guest&conference=VAC000056916@pexip.mapsandbox.net&pin=351792&aid=0703f6b2-a033-489a-bf54-1162e6f3019d#",
              "group": true,
              "vvsKind": "CLINIC_BASED"
            },
            "extension": {
              "ccLocation": {
              "address": {}
              },
              "vistaStatus": [],
              "patientHasMobileGfe": false
            },
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
    let(:video_appt_struct_data) do
      struct = JSON.parse(vaos_video_appointment_data, object_class: OpenStruct)
      struct.data
    end
    let(:atlas_struct_data) do
      address = OpenStruct.new(streetAddress: '5929 Georgia Ave NW', city: 'Washington', state: 'DC', zipCode: '20011',
                               country: 'USA', latitutde: 38.961979, longitude: -77.027908, additionalDetails: '')
      OpenStruct.new(siteCode: 'VFW-DC-20011-02', confirmationCode: '075041', address:)
    end

    let(:appointment1) do
      {
        id: '180770',
        type: :appointments,
        attributes: {
          kind: 'telehealth',
          status: 'booked',
          serviceType: 'amputation',
          locationId: '983GC',
          clinic: '1081',
          start: '2023-11-13T16:00:00Z',
          end: '2023-11-13T16:30:00Z',
          minutesDuration: 30,
          telehealth: {
            vvsKind: 'CLINIC_BASED',
            atlas: nil
          },
          extension: {
            preCheckinAllowed: nil,
            eCheckinAllowed: nil,
            patientHasMobileGfe: false
          },
          serviceCategory: nil,
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

    let(:serialized_hash_response) do
      {
        data: [appointment1]
      }
    end

    it 'returns a serialized hash' do
      serializer = subject.new(video_appt_struct_data)
      expect(serializer.serializable_hash).to eq(serialized_hash_response)
    end
  end

  context 'for valid vaos claim appointment data' do
    let(:vaos_claim_appointment_data) do
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
            "kind": "telehealth",
            "status": "booked",
            "serviceType": "amputation",
            "patientIcn": "1013125218V696863",
            "locationId": "983GC",
            "clinic": "1081",
            "start": "2023-11-13T16:00:00Z",
            "end": "2023-11-13T16:30:00Z",
            "minutesDuration": 30,
            "serviceCategory": [
              {
              "coding": [
                {
                  "system": "http://www.va.gov/Terminology/VistADefinedTerms/409_1",
                  "code": "REGULAR",
                  "display": "REGULAR"
                }
              ],
              "text": "COMPENSATION & PENSION"
              }
            ],
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
          }
       ]
      }'
    end
    let(:claim_appt_struct_data) do
      struct = JSON.parse(vaos_claim_appointment_data, object_class: OpenStruct)
      struct.data
    end
    let(:atlas_struct_data) do
      address = OpenStruct.new(streetAddress: '5929 Georgia Ave NW', city: 'Washington', state: 'DC', zipCode: '20011',
                               country: 'USA', latitutde: 38.961979, longitude: -77.027908, additionalDetails: '')
      OpenStruct.new(siteCode: 'VFW-DC-20011-02', confirmationCode: '075041', address:)
    end
    let(:appointment1) do
      {
        id: '180766',
        type: :appointments,
        attributes: {
          kind: 'telehealth',
          status: 'booked',
          serviceType: 'amputation',
          locationId: '983GC',
          clinic: '1081',
          start: '2023-11-13T16:00:00Z',
          end: '2023-11-13T16:30:00Z',
          minutesDuration: 30,
          telehealth: {
            vvsKind: nil,
            atlas: nil
          },
          extension: {
            preCheckinAllowed: nil,
            eCheckinAllowed: nil,
            patientHasMobileGfe: nil
          },
          serviceCategory: [
            {
              text: 'COMPENSATION & PENSION'
            }
          ],
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

    let(:serialized_hash_response) do
      {
        data: [appointment1]
      }
    end

    it 'returns a serialized hash' do
      serializer = subject.new(claim_appt_struct_data)
      expect(serializer.serializable_hash).to eq(serialized_hash_response)
    end
  end
end
