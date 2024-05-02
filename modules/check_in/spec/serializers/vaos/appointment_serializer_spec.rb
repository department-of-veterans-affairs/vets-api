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
            },
            {
              "system": "http://www.va.gov/Terminology/VistADefinedTerms/409_84",
              "value": "983:10876"
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
          "created": "2023-08-02T00:00:00Z",
          "cancellable": true
        },
        {
          "id": "180770",
          "identifier": [
            {
              "system": "Appointment/",
              "value": "413938333130383736"
            },
            {
              "system": "http://www.va.gov/Terminology/VistADefinedTerms/409_84",
              "value": "983:10876"
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
          "created": "2023-08-02T00:00:00Z",
          "cancellable": true
         }
       ]
    }'
  end
  let(:appt_struct_data) do
    struct = JSON.parse(vaos_appointment_data, object_class: OpenStruct)
    struct.data
  end

  context 'For valid vaos appointment data' do
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
          minutesDuration: 30
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
          minutesDuration: 30
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
end
