# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V1::Prescriptions::RefillTransformer do
  describe '#transform' do
    let(:transformer) { described_class.new }

    context 'with successful and failed refills' do
      let(:uhd_response) do
        {
          success: [
            { id: 123, name: 'METFORMIN HCL 500MG TAB', status: 'submitted' },
            { id: 456, name: 'LISINOPRIL 10MG TAB', status: 'submitted' }
          ],
          failed: [
            { id: 789, name: 'ASPIRIN 81MG TAB', error: 'Not refillable' },
            { id: 101, name: 'VITAMIN D 1000IU TAB', error: 'Prescription expired' }
          ]
        }
      end

      it 'transforms to v0 API format' do
        result = transformer.transform(uhd_response)

        expect(result).to be_a(Hash)
        expect(result).to include(
          :failed_station_list,
          :successful_station_list,
          :last_updated_time,
          :prescription_list,
          :failed_prescription_ids,
          :errors,
          :info_messages
        )
      end

      it 'extracts station lists correctly' do
        result = transformer.transform(uhd_response)

        expect(result[:successful_station_list]).to eq(['123', '456'])
        expect(result[:failed_station_list]).to eq(['789', '101'])
      end

      it 'builds prescription list correctly' do
        result = transformer.transform(uhd_response)

        prescription_list = result[:prescription_list]
        expect(prescription_list).to be_an(Array)
        expect(prescription_list.size).to eq(4)

        # Check successful prescriptions
        successful_prescriptions = prescription_list.select { |p| p[:success] }
        expect(successful_prescriptions.size).to eq(2)
        expect(successful_prescriptions.first[:prescription_id]).to eq(123)
        expect(successful_prescriptions.first[:prescription_name]).to eq('METFORMIN HCL 500MG TAB')

        # Check failed prescriptions
        failed_prescriptions = prescription_list.select { |p| p[:success] == false }
        expect(failed_prescriptions.size).to eq(2)
        expect(failed_prescriptions.first[:prescription_id]).to eq(789)
        expect(failed_prescriptions.first[:error_message]).to eq('Not refillable')
      end

      it 'extracts failed prescription IDs' do
        result = transformer.transform(uhd_response)

        expect(result[:failed_prescription_ids]).to eq([789, 101])
      end

      it 'builds error messages correctly' do
        result = transformer.transform(uhd_response)

        errors = result[:errors]
        expect(errors).to be_an(Array)
        expect(errors.size).to eq(2)
        expect(errors.first[:developer_message]).to include('Prescription ID: 789')
        expect(errors.first[:error_code]).to eq('REFILL_ERROR')
      end

      it 'builds info messages' do
        result = transformer.transform(uhd_response)

        info_messages = result[:info_messages]
        expect(info_messages).to include('Successfully submitted 2 prescription(s) for refill')
        expect(info_messages).to include('Failed to submit 2 prescription(s) for refill')
      end

      it 'includes current timestamp' do
        freeze_time = Time.current
        allow(Time).to receive(:current).and_return(freeze_time)

        result = transformer.transform(uhd_response)

        expect(result[:last_updated_time]).to eq(freeze_time.iso8601)
      end
    end

    context 'with only successful refills' do
      let(:uhd_response) do
        {
          success: [
            { id: 123, name: 'METFORMIN HCL 500MG TAB', status: 'submitted' }
          ],
          failed: []
        }
      end

      it 'handles success-only response' do
        result = transformer.transform(uhd_response)

        expect(result[:successful_station_list]).to eq(['123'])
        expect(result[:failed_station_list]).to eq([])
        expect(result[:prescription_list].size).to eq(1)
        expect(result[:failed_prescription_ids]).to eq([])
        expect(result[:errors]).to eq([])
        expect(result[:info_messages]).to include('Successfully submitted 1 prescription(s) for refill')
      end
    end

    context 'with only failed refills' do
      let(:uhd_response) do
        {
          success: [],
          failed: [
            { id: 789, name: 'ASPIRIN 81MG TAB', error: 'Not refillable' }
          ]
        }
      end

      it 'handles failure-only response' do
        result = transformer.transform(uhd_response)

        expect(result[:successful_station_list]).to eq([])
        expect(result[:failed_station_list]).to eq(['789'])
        expect(result[:prescription_list].size).to eq(1)
        expect(result[:failed_prescription_ids]).to eq([789])
        expect(result[:errors].size).to eq(1)
        expect(result[:info_messages]).to include('Failed to submit 1 prescription(s) for refill')
      end
    end

    context 'with empty response' do
      let(:uhd_response) do
        {
          success: [],
          failed: []
        }
      end

      it 'handles empty response' do
        result = transformer.transform(uhd_response)

        expect(result[:successful_station_list]).to eq([])
        expect(result[:failed_station_list]).to eq([])
        expect(result[:prescription_list]).to eq([])
        expect(result[:failed_prescription_ids]).to eq([])
        expect(result[:errors]).to eq([])
        expect(result[:info_messages]).to eq([])
      end
    end

    context 'with missing prescription names' do
      let(:uhd_response) do
        {
          success: [{ id: 123, status: 'submitted' }],
          failed: [{ id: 789, error: 'Not refillable' }]
        }
      end

      it 'handles missing prescription names gracefully' do
        result = transformer.transform(uhd_response)

        prescription_list = result[:prescription_list]
        expect(prescription_list.first[:prescription_name]).to eq('Unknown')
        expect(prescription_list.last[:prescription_name]).to eq('Unknown')
      end
    end
  end
end
