# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/serializers/prescription_serializer'

RSpec.describe UnifiedHealthData::Serializers::PrescriptionSerializer do
  subject { described_class.new(prescription) }

  let(:prescription) do
    UnifiedHealthData::Prescription.new(
      id: '12345',
      type: 'Prescription',
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
      tracking: [
        {
          prescription_name: 'METFORMIN HCL 500MG TAB',
          prescription_number: 'RX123456',
          ndc_number: '00123456789',
          prescription_id: 12_345,
          tracking_number: '1Z999AA1234567890',
          shipped_date: '2023-05-16T00:00:00.000Z',
          carrier: 'UPS',
          other_prescriptions: []
        }
      ],
      instructions: 'Take twice daily with meals',
      facility_phone_number: '555-123-4567',
      prescription_source: 'VA',
      remarks: 'Patient should monitor blood sugar levels',
      cmop_ndc_number: '00093721410',
      disp_status: 'Active'
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
      expect(attributes[:type]).to eq('Prescription')
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
      expect(attributes[:remarks]).to eq('Patient should monitor blood sugar levels')

      # tracking
      expect(attributes[:tracking]).to be_an(Array)
      expect(attributes[:tracking].first).to include(
        prescription_name: 'METFORMIN HCL 500MG TAB',
        tracking_number: '1Z999AA1234567890',
        carrier: 'UPS'
      )

      # cmop_ndc_number
      expect(attributes[:cmop_ndc_number]).to eq('00093721410')

      # disp_status
      expect(attributes[:disp_status]).to eq('Active')
    end
  end

  describe 'disp_status serialization' do
    context 'when prescription has disp_status set' do
      let(:prescription_with_disp_status) do
        UnifiedHealthData::Prescription.new(
          id: '67890',
          type: 'Prescription',
          refill_status: 'active',
          prescription_source: 'NV',
          disp_status: 'Active: Non-VA'
        )
      end

      it 'includes disp_status in serialized output' do
        serializer = described_class.new(prescription_with_disp_status)
        result = serializer.serializable_hash
        attributes = result[:data][:attributes]

        expect(attributes[:disp_status]).to eq('Active: Non-VA')
      end
    end

    context 'when prescription has nil disp_status' do
      let(:prescription_without_disp_status) do
        UnifiedHealthData::Prescription.new(
          id: '11111',
          type: 'Prescription',
          refill_status: 'active',
          prescription_source: 'VA',
          disp_status: nil
        )
      end

      it 'includes disp_status as nil in serialized output' do
        serializer = described_class.new(prescription_without_disp_status)
        result = serializer.serializable_hash
        attributes = result[:data][:attributes]

        expect(attributes[:disp_status]).to be_nil
      end
    end
  end
end
