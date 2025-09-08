# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V1::Prescriptions::Transformer do
  describe '#transform' do
    let(:uhd_prescription) do
      UnifiedHealthData::Prescription.new(
        id: '123456',
        type: 'prescription',
        attributes: UnifiedHealthData::PrescriptionAttributes.new(
          prescription_name: 'METFORMIN HCL 500MG TAB',
          refill_status: 'active',
          refill_submit_date: '2024-01-15',
          refill_date: '2024-01-20',
          refill_remaining: 3,
          facility_name: 'CHEYENNE VA MEDICAL CENTER',
          ordered_date: '2023-12-01',
          quantity: '90',
          expiration_date: '2024-12-01',
          prescription_number: 'RX123456',
          dispensed_date: '2023-12-05',
          station_number: '442',
          is_refillable: true,
          is_trackable: true,
          instructions: 'Take one tablet by mouth twice daily with meals',
          facility_phone_number: '307-778-7550',
          data_source_system: 'vista'
        )
      )
    end

    let(:transformer) { described_class.new }

    context 'with valid UHD prescriptions' do
      it 'transforms single prescription correctly' do
        result = transformer.transform([uhd_prescription])

        expect(result).to be_an(Array)
        expect(result.size).to eq(1)

        transformed = result.first
        expect(transformed.prescription_id).to eq('123456')
        expect(transformed.prescription_name).to eq('METFORMIN HCL 500MG TAB')
        expect(transformed.refill_status).to eq('active')
        expect(transformed.refill_remaining).to eq(3)
        expect(transformed.facility_name).to eq('CHEYENNE VA MEDICAL CENTER')
        expect(transformed.is_refillable).to be(true)
        expect(transformed.is_trackable).to be(true)
        expect(transformed.instructions).to eq('Take one tablet by mouth twice daily with meals')
        expect(transformed.data_source_system).to eq('vista')
      end

      it 'creates OpenStruct objects for dot notation access' do
        result = transformer.transform([uhd_prescription])
        transformed = result.first

        expect(transformed).to be_a(OpenStruct)
        expect(transformed.prescription_name).to eq('METFORMIN HCL 500MG TAB')
        expect(transformed.facility_name).to eq('CHEYENNE VA MEDICAL CENTER')
      end
    end

    context 'with empty or nil input' do
      it 'returns empty array for nil input' do
        result = transformer.transform(nil)
        expect(result).to eq([])
      end

      it 'returns empty array for empty array input' do
        result = transformer.transform([])
        expect(result).to eq([])
      end
    end

    context 'with prescription missing some attributes' do
      let(:minimal_prescription) do
        UnifiedHealthData::Prescription.new(
          id: '999',
          type: 'prescription',
          attributes: UnifiedHealthData::PrescriptionAttributes.new(
            prescription_name: 'MINIMAL DRUG',
            refill_status: 'active'
          )
        )
      end

      it 'handles missing attributes gracefully' do
        result = transformer.transform([minimal_prescription])

        transformed = result.first
        expect(transformed.prescription_id).to eq('999')
        expect(transformed.prescription_name).to eq('MINIMAL DRUG')
        expect(transformed.refill_status).to eq('active')
        expect(transformed.refill_remaining).to be_nil
        expect(transformed.facility_name).to be_nil
        expect(transformed.is_refillable).to be_nil
        expect(transformed.is_trackable).to be_nil
      end
    end
  end
end