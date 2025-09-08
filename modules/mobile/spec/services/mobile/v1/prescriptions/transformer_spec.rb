# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'

RSpec.describe Mobile::V1::Prescriptions::Transformer do
  describe '.transform' do
    let(:uhd_prescription) do
      {
        prescription_id: '12345',
        medication_name: 'Test Medication 100mg',
        instructions: 'Take twice daily with food',
        fill_date: '2024-01-15',
        prescribed_date: '2024-01-10',
        expiration_date: '2025-01-10',
        quantity: 60,
        refills_remaining: 3,
        status: 'active',
        prescriber_name: 'Dr. Jane Smith',
        pharmacy_name: 'VA Medical Center Pharmacy',
        rx_number: 'RX67890',
        ordered_date: '2024-01-12',
        ndc_number: '12345-678-90',
        prescription_source: 'VISTA'
      }
    end

    it 'transforms UHD prescription to mobile v0 format' do
      result = described_class.transform(uhd_prescription)

      expect(result).to eq({
        prescriptionId: 12345,
        prescriptionNumber: 'RX67890',
        prescriptionName: 'Test Medication 100mg',
        refillStatus: 'active',
        refillSubmitDate: nil,
        refillDate: '2024-01-15T00:00:00.000Z',
        refillRemaining: 3,
        facilityName: 'VA Medical Center Pharmacy',
        isRefillable: true,
        isTrackable: false,
        orderedDate: '2024-01-12T00:00:00.000Z',
        quantity: 60,
        expirationDate: '2025-01-10T00:00:00.000Z',
        prescribedDate: '2024-01-10T00:00:00.000Z',
        stationNumber: nil,
        instructions: 'Take twice daily with food',
        dispensedDate: nil,
        sig: 'Take twice daily with food',
        ndcNumber: '12345-678-90',
        prescriptionSource: 'UHD'
      })
    end

    context 'with minimal prescription data' do
      let(:minimal_prescription) do
        {
          prescription_id: '98765',
          medication_name: 'Basic Med',
          status: 'expired'
        }
      end

      it 'handles missing fields gracefully' do
        result = described_class.transform(minimal_prescription)

        expect(result).to eq({
          prescriptionId: 98765,
          prescriptionNumber: nil,
          prescriptionName: 'Basic Med',
          refillStatus: 'expired',
          refillSubmitDate: nil,
          refillDate: nil,
          refillRemaining: nil,
          facilityName: nil,
          isRefillable: false,
          isTrackable: false,
          orderedDate: nil,
          quantity: nil,
          expirationDate: nil,
          prescribedDate: nil,
          stationNumber: nil,
          instructions: nil,
          dispensedDate: nil,
          sig: nil,
          ndcNumber: nil,
          prescriptionSource: 'UHD'
        })
      end
    end

    context 'with refillable status' do
      let(:refillable_prescription) do
        {
          prescription_id: '11111',
          medication_name: 'Refillable Med',
          status: 'active',
          refills_remaining: 2
        }
      end

      it 'sets isRefillable to true when refills remaining and status is active' do
        result = described_class.transform(refillable_prescription)
        expect(result[:isRefillable]).to be true
      end
    end

    context 'with non-refillable status' do
      let(:non_refillable_prescription) do
        {
          prescription_id: '22222',
          medication_name: 'Non-refillable Med',
          status: 'expired',
          refills_remaining: 0
        }
      end

      it 'sets isRefillable to false when no refills remaining or status is not active' do
        result = described_class.transform(non_refillable_prescription)
        expect(result[:isRefillable]).to be false
      end
    end

    context 'with date formatting' do
      let(:prescription_with_dates) do
        {
          prescription_id: '33333',
          medication_name: 'Med with Dates',
          fill_date: '2024-03-15',
          prescribed_date: '2024-03-01T10:30:00',
          expiration_date: '2025-03-01',
          ordered_date: '2024-03-02T15:45:30Z'
        }
      end

      it 'formats dates consistently to ISO 8601 with Z suffix' do
        result = described_class.transform(prescription_with_dates)

        expect(result[:refillDate]).to eq('2024-03-15T00:00:00.000Z')
        expect(result[:prescribedDate]).to eq('2024-03-01T10:30:00.000Z')
        expect(result[:expirationDate]).to eq('2025-03-01T00:00:00.000Z')
        expect(result[:orderedDate]).to eq('2024-03-02T15:45:30.000Z')
      end
    end

    context 'when prescription_id is string' do
      let(:string_id_prescription) do
        {
          prescription_id: '999888',
          medication_name: 'String ID Med'
        }
      end

      it 'converts prescription_id to integer' do
        result = described_class.transform(string_id_prescription)
        expect(result[:prescriptionId]).to eq(999888)
      end
    end

    context 'when prescription_id is nil' do
      let(:nil_id_prescription) do
        {
          prescription_id: nil,
          medication_name: 'Nil ID Med'
        }
      end

      it 'handles nil prescription_id' do
        result = described_class.transform(nil_id_prescription)
        expect(result[:prescriptionId]).to be_nil
      end
    end
  end
end
