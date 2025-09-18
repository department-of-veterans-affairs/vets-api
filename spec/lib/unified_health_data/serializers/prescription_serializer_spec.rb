# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/serializers/prescription_serializer'

RSpec.describe UnifiedHealthData::Serializers::PrescriptionSerializer do
  subject { described_class.new(prescription) }

  let(:prescription) do
    UnifiedHealthData::Prescription.new(
      id: '12345',
      refill_status: 'active',
      refill_submit_date: '2023-05-15',
      refill_date: '2023-05-20',
      refill_remaining: 2,
      facility_name: 'VA Medical Center',
      ordered_date: '2023-05-10',
      quantity: '30',
      expiration_date: '2024-05-10',
      prescription_number: 'RX123456',
      prescription_name: 'METFORMIN HCL 500MG TAB',
      dispensed_date: '2023-05-15',
      station_number: '589',
      is_refillable: true,
      is_trackable: true,
      tracking_information: {},
      instructions: 'Take twice daily with meals',
      facility_phone_number: '555-123-4567',
      prescription_source: 'VA'
    )
  end

  describe 'serialization' do
    it 'serializes core, aliased, and tracking attributes' do
      result = subject.serializable_hash
      data = result[:data]
      attributes = data[:attributes]

      # type/id
      expect(data[:type]).to eq(:prescription)
      expect(data[:id]).to eq('12345')

      # core attributes
      expect(attributes[:refill_status]).to eq('active')
      expect(attributes[:refill_remaining]).to eq(2)
      expect(attributes[:facility_name]).to eq('VA Medical Center')
      expect(attributes[:prescription_name]).to eq('METFORMIN HCL 500MG TAB')
      expect(attributes[:is_refillable]).to be(true)
      expect(attributes[:is_trackable]).to be(true)
      expect(attributes[:prescription_source]).to eq('VA')

      # aliased attributes
      expect(attributes[:instructions]).to eq('Take twice daily with meals')
      expect(attributes[:facility_phone_number]).to eq('555-123-4567')

      # tracking
      expect(attributes[:tracking_information]).to eq({})
    end

    context 'when tracking_information is empty' do
      let(:prescription) do
        UnifiedHealthData::Prescription.new(
          id: '67890',
          refill_status: 'active',
          prescription_name: 'LISINOPRIL 10MG TAB',
          is_refillable: false,
          is_trackable: false,
          prescription_source: 'VA'
        )
      end

      it 'includes empty tracking_information hash' do
        result = subject.serializable_hash
        expect(result[:data][:attributes][:tracking_information]).to eq({})
      end
    end
  end
end
