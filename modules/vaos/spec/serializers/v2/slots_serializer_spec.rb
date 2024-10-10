# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::SlotsSerializer do
  describe 'json serialization' do
    context 'with a slot' do
      let(:slot) do
        OpenStruct.new(
          id: '123',
          start: '2021-10-26T22:00:00Z',
          end: '2021-10-27T00:00:00Z'
        )
      end

      it 'serializes correctly' do
        expect(VAOS::V2::SlotsSerializer.new(slot).serializable_hash.to_json).to eq(
          '{"data":{"id":"123","type":"slots","attributes":{"start":"2021-10-26T22:00:00Z"' \
          ',"end":"2021-10-27T00:00:00Z","location_id":null,"clinic_ien":null,"practitioner_name":null}}}'
        )
      end
    end

    context 'with a slot with location, clinic, and practitioner data' do
      let(:slot_all_fields) do
        OpenStruct.new(
          id: '123',
          start: '2021-10-26T22:00:00Z',
          end: '2021-10-27T00:00:00Z',
          location: { vha_facility_id: '757GC', name: 'Marion VA Clinic' },
          practitioner: { name: 'Doe, John D, MD', cerner_id: 'Practitioner/123456' },
          clinic: { clinic_ien: '123', name: 'MARION CBOC PODIATRY' }
        )
      end

      it 'serializes correctly' do
        expect(VAOS::V2::SlotsSerializer.new(slot_all_fields).serializable_hash.to_json).to eq(
          '{"data":{"id":"123","type":"slots","attributes":{"start":"2021-10-26T22:00:00Z"' \
          ',"end":"2021-10-27T00:00:00Z","location_id":"757GC","clinic_ien":"123"' \
          ',"practitioner_name":"Doe, John D, MD"}}}'
        )
      end
    end
  end
end
