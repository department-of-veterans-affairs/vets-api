# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'

RSpec.describe Mobile::V1::Prescriptions::RefillTransformer do
  describe '.transform' do
    let(:successful_uhd_response) do
      {
        status: 'success',
        refilled_prescriptions: [
          {
            prescription_id: '12345',
            status: 'refilled',
            fill_date: '2024-01-20',
            station: 'STATION123'
          },
          {
            prescription_id: '67890',
            status: 'refilled',
            fill_date: '2024-01-20',
            station: 'STATION456'
          }
        ],
        failed_prescriptions: [],
        errors: []
      }
    end

    it 'transforms successful UHD refill response to mobile v0 format' do
      result = described_class.transform(successful_uhd_response)

      expect(result).to eq({
        failedStationList: '',
        successfulStationList: 'STATION123, STATION456',
        lastUpdatedTime: be_present,
        prescriptionList: nil,
        failedPrescriptionIds: [],
        errors: [],
        infoMessages: []
      })
    end

    context 'with mixed success and failure' do
      let(:mixed_uhd_response) do
        {
          status: 'partial_success',
          refilled_prescriptions: [
            {
              prescription_id: '12345',
              status: 'refilled',
              fill_date: '2024-01-20',
              station: 'STATION123'
            }
          ],
          failed_prescriptions: [
            {
              prescription_id: '67890',
              error_code: 139,
              error_message: 'Prescription not refillable',
              station: 'STATION456'
            }
          ],
          errors: ['Prescription not refillable for id: 67890']
        }
      end

      it 'transforms mixed response correctly' do
        result = described_class.transform(mixed_uhd_response)

        expect(result).to eq({
          failedStationList: 'STATION456',
          successfulStationList: 'STATION123',
          lastUpdatedTime: be_present,
          prescriptionList: nil,
          failedPrescriptionIds: ['67890'],
          errors: [{
            errorCode: 139,
            developerMessage: 'Prescription not refillable for id : 67890',
            message: 'Prescription not refillable'
          }],
          infoMessages: []
        })
      end
    end

    context 'with all failures' do
      let(:failure_uhd_response) do
        {
          status: 'error',
          refilled_prescriptions: [],
          failed_prescriptions: [
            {
              prescription_id: '11111',
              error_code: 139,
              error_message: 'Prescription not refillable',
              station: 'STATION789'
            },
            {
              prescription_id: '22222',
              error_code: 140,
              error_message: 'Prescription expired',
              station: 'STATION999'
            }
          ],
          errors: [
            'Prescription not refillable for id: 11111',
            'Prescription expired for id: 22222'
          ]
        }
      end

      it 'transforms failure response correctly' do
        result = described_class.transform(failure_uhd_response)

        expect(result).to eq({
          failedStationList: 'STATION789, STATION999',
          successfulStationList: '',
          lastUpdatedTime: be_present,
          prescriptionList: nil,
          failedPrescriptionIds: ['11111', '22222'],
          errors: [
            {
              errorCode: 139,
              developerMessage: 'Prescription not refillable for id : 11111',
              message: 'Prescription not refillable'
            },
            {
              errorCode: 140,
              developerMessage: 'Prescription expired for id : 22222',
              message: 'Prescription expired'
            }
          ],
          infoMessages: []
        })
      end
    end

    context 'with missing station information' do
      let(:no_station_response) do
        {
          status: 'success',
          refilled_prescriptions: [
            {
              prescription_id: '12345',
              status: 'refilled',
              fill_date: '2024-01-20'
              # station missing
            }
          ],
          failed_prescriptions: [],
          errors: []
        }
      end

      it 'handles missing station gracefully' do
        result = described_class.transform(no_station_response)

        expect(result[:successfulStationList]).to eq('')
        expect(result[:failedStationList]).to eq('')
      end
    end

    context 'with empty response' do
      let(:empty_response) do
        {
          status: 'success',
          refilled_prescriptions: [],
          failed_prescriptions: [],
          errors: []
        }
      end

      it 'handles empty response correctly' do
        result = described_class.transform(empty_response)

        expect(result).to eq({
          failedStationList: '',
          successfulStationList: '',
          lastUpdatedTime: be_present,
          prescriptionList: nil,
          failedPrescriptionIds: [],
          errors: [],
          infoMessages: []
        })
      end
    end

    context 'with duplicate stations' do
      let(:duplicate_stations_response) do
        {
          status: 'success',
          refilled_prescriptions: [
            {
              prescription_id: '12345',
              status: 'refilled',
              station: 'STATION123'
            },
            {
              prescription_id: '67890',
              status: 'refilled',
              station: 'STATION123'
            }
          ],
          failed_prescriptions: [],
          errors: []
        }
      end

      it 'removes duplicate stations from list' do
        result = described_class.transform(duplicate_stations_response)
        expect(result[:successfulStationList]).to eq('STATION123')
      end
    end

    context 'with nil error codes' do
      let(:nil_error_code_response) do
        {
          status: 'error',
          refilled_prescriptions: [],
          failed_prescriptions: [
            {
              prescription_id: '12345',
              error_code: nil,
              error_message: 'Unknown error'
            }
          ],
          errors: ['Unknown error for id: 12345']
        }
      end

      it 'handles nil error codes' do
        result = described_class.transform(nil_error_code_response)

        expect(result[:errors].first).to eq({
          errorCode: nil,
          developerMessage: 'Unknown error for id : 12345',
          message: 'Unknown error'
        })
      end
    end
  end
end
