# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe Mobile::V1::Prescriptions::Transformer do
  describe '#transform' do
    let(:transformer) { described_class.new }
    let(:uhd_prescription) do
      double('UHD Prescription',
        prescription_id: '12345',
        prescription_number: 'RX67890',
        prescription_name: 'Test Medication 100mg',
        refill_status: 'active',
        refill_submit_date: '2024-01-14',
        refill_date: '2024-01-15',
        refill_remaining: 3,
        facility_name: 'VA Medical Center Pharmacy',
        refillable?: true,
        trackable?: false,
        ordered_date: '2024-01-12',
        quantity: 60,
        expiration_date: '2025-01-10',
        prescribed_date: '2024-01-10',
        station_number: 'ST123',
        sig: 'Take twice daily with food',
        dispensed_date: nil,
        ndc_number: '12345-678-90',
        cmop_division_phone: '555-1234',
        attributes: double(data_source_system: 'VISTA')
      )
    end

    it 'transforms UHD prescription to Mobile::V1::TransformedPrescription' do
      result = transformer.transform([uhd_prescription]).first

      expect(result).to be_a(Mobile::V1::TransformedPrescription)
      expect(result.prescription_id).to eq(12345)
      expect(result.prescription_number).to eq('RX67890')
      expect(result.prescription_name).to eq('Test Medication 100mg')
      expect(result.refill_status).to eq('active')
      expect(result.refill_remaining).to eq(3)
      expect(result.facility_name).to eq('VA Medical Center Pharmacy')
      expect(result.is_refillable).to be true
      expect(result.is_trackable).to be false
      expect(result.quantity).to eq(60)
      expect(result.instructions).to eq('Take twice daily with food')
      expect(result.sig).to eq('Take twice daily with food')
      expect(result.ndc_number).to eq('12345-678-90')
      expect(result.prescription_source).to eq('UHD')
      expect(result.data_source_system).to eq('VISTA')
    end

    context 'with minimal prescription data' do
      let(:minimal_prescription) do
        double('Minimal UHD Prescription',
          prescription_id: '98765',
          prescription_number: nil,
          prescription_name: 'Basic Med',
          refill_status: 'expired',
          refill_submit_date: nil,
          refill_date: nil,
          refill_remaining: nil,
          facility_name: nil,
          refillable?: false,
          trackable?: false,
          ordered_date: nil,
          quantity: nil,
          expiration_date: nil,
          prescribed_date: nil,
          station_number: nil,
          sig: nil,
          dispensed_date: nil,
          ndc_number: nil,
          cmop_division_phone: nil,
          attributes: nil
        )
      end

      it 'handles missing fields gracefully' do
        result = transformer.transform([minimal_prescription]).first

        expect(result).to be_a(Mobile::V1::TransformedPrescription)
        expect(result.prescription_id).to eq(98765)
        expect(result.prescription_name).to eq('Basic Med')
        expect(result.refill_status).to eq('expired')
        expect(result.prescription_number).to be_nil
        expect(result.refill_remaining).to be_nil
        expect(result.facility_name).to be_nil
        expect(result.is_refillable).to be false
        expect(result.is_trackable).to be false
        expect(result.quantity).to be_nil
        expect(result.instructions).to be_nil
        expect(result.prescription_source).to eq('UHD')
        expect(result.data_source_system).to be_nil
      end
    end

    context 'when prescription_id is string' do
      let(:string_id_prescription) do
        double('String ID UHD Prescription',
          prescription_id: '999888',
          prescription_number: nil,
          prescription_name: 'String ID Med',
          refill_status: nil,
          refill_submit_date: nil,
          refill_date: nil,
          refill_remaining: nil,
          facility_name: nil,
          refillable?: false,
          trackable?: false,
          ordered_date: nil,
          quantity: nil,
          expiration_date: nil,
          prescribed_date: nil,
          station_number: nil,
          sig: nil,
          dispensed_date: nil,
          ndc_number: nil,
          cmop_division_phone: nil,
          attributes: nil
        )
      end

      it 'converts prescription_id to integer' do
        result = transformer.transform([string_id_prescription]).first
        expect(result.prescription_id).to eq(999888)
      end
    end

    context 'with empty input' do
      it 'returns empty array for nil input' do
        result = transformer.transform(nil)
        expect(result).to eq([])
      end

      it 'returns empty array for empty array input' do
        result = transformer.transform([])
        expect(result).to eq([])
      end
    end
  end
end
