# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/serializers/prescriptions_refills_serializer'

RSpec.describe UnifiedHealthData::Serializers::PrescriptionsRefillsSerializer, type: :serializer do
  let(:id) { SecureRandom.uuid }

  describe '#initialize' do
    context 'with failed refills format' do
      let(:resource) do
        {
          success: [],
          failed: [
            {
              id: '15215488543',
              error: '^ER:Error:',
              station_number: '556'
            }
          ]
        }
      end

      it 'correctly processes failed refills' do
        serializer = described_class.new(id, resource)
        result = serializer.serializable_hash

        expect(result[:data][:type]).to eq(:PrescriptionRefills)
        expect(result[:data][:attributes][:failed_prescription_ids]).to eq(['15215488543'])
        expect(result[:data][:attributes][:failed_station_list]).to eq(['556'])
        expect(result[:data][:attributes][:successful_station_list]).to eq([])
        expect(result[:data][:attributes][:prescription_list]).to eq([])
        expect(result[:data][:attributes][:last_updated_time]).to be_present
        expect(result[:data][:attributes][:info_messages]).to eq([])
        expect(result[:data][:attributes][:errors]).to eq([
                                                            {
                                                              developer_message: '^ER:Error:',
                                                              prescription_id: '15215488543',
                                                              station_number: '556'
                                                            }
                                                          ])
      end

      it 'logs failed refills with correct format' do
        expect(Rails.logger).to receive(:warn).with(
          'Prescription refill failed',
          developer_message: '^ER:Error:',
          prescription_id_last_four: '8543',
          station_number: '556'
        )

        described_class.new(id, resource)
      end
    end

    context 'with successful refills format' do
      let(:resource) do
        {
          success: [
            {
              id: '12345',
              status: 'submitted',
              station_number: '123'
            }
          ],
          failed: []
        }
      end

      it 'correctly processes successful refills' do
        serializer = described_class.new(id, resource)
        result = serializer.serializable_hash

        expect(result[:data][:type]).to eq(:PrescriptionRefills)
        expect(result[:data][:attributes][:failed_prescription_ids]).to eq([])
        expect(result[:data][:attributes][:failed_station_list]).to eq([])
        expect(result[:data][:attributes][:successful_station_list]).to eq(['123'])
        expect(result[:data][:attributes][:last_updated_time]).to be_present
        expect(result[:data][:attributes][:prescription_list]).to eq([
                                                                       {
                                                                         id: '12345',
                                                                         status: 'submitted',
                                                                         station_number: '123'
                                                                       }
                                                                     ])
        expect(result[:data][:attributes][:info_messages]).to eq([
                                                                   {
                                                                     prescription_id: '12345',
                                                                     message: 'submitted',
                                                                     station_number: '123'
                                                                   }
                                                                 ])
        expect(result[:data][:attributes][:errors]).to eq([])
      end
    end

    context 'with same station having both success and failure' do
      let(:resource) do
        {
          success: [
            {
              id: '15214174591',
              status: 'submitted',
              station_number: '556'
            }
          ],
          failed: [
            {
              id: '15215488543',
              error: '^ER:Error:',
              station_number: '556'
            }
          ]
        }
      end

      it 'correctly handles same station with both success and failure' do
        serializer = described_class.new(id, resource)
        result = serializer.serializable_hash

        expect(result[:data][:type]).to eq(:PrescriptionRefills)
        expect(result[:data][:attributes][:failed_prescription_ids]).to eq(['15215488543'])
        expect(result[:data][:attributes][:failed_station_list]).to eq(['556'])
        expect(result[:data][:attributes][:successful_station_list]).to eq(['556'])
        expect(result[:data][:attributes][:last_updated_time]).to be_present
        expect(result[:data][:attributes][:prescription_list]).to eq([
                                                                       {
                                                                         id: '15214174591',
                                                                         status: 'submitted',
                                                                         station_number: '556'
                                                                       }
                                                                     ])
        expect(result[:data][:attributes][:info_messages]).to eq([
                                                                   {
                                                                     prescription_id: '15214174591',
                                                                     message: 'submitted',
                                                                     station_number: '556'
                                                                   }
                                                                 ])
        expect(result[:data][:attributes][:errors]).to eq([
                                                            {
                                                              developer_message: '^ER:Error:',
                                                              prescription_id: '15215488543',
                                                              station_number: '556'
                                                            }
                                                          ])
      end
    end

    context 'with multiple failures from same station' do
      let(:resource) do
        {
          success: [],
          failed: [
            {
              id: '11111',
              error: 'Prescription expired',
              station_number: '556'
            },
            {
              id: '22222',
              error: 'Not refillable',
              station_number: '556'
            },
            {
              id: '33333',
              error: 'Invalid prescription',
              station_number: '556'
            }
          ]
        }
      end

      it 'correctly processes multiple failures from same station' do
        serializer = described_class.new(id, resource)
        result = serializer.serializable_hash

        expect(result[:data][:type]).to eq(:PrescriptionRefills)
        expect(result[:data][:attributes][:failed_prescription_ids]).to eq(%w[11111 22222 33333])
        expect(result[:data][:attributes][:failed_station_list]).to eq(['556'])
        expect(result[:data][:attributes][:successful_station_list]).to eq([])
        expect(result[:data][:attributes][:last_updated_time]).to be_present
        expect(result[:data][:attributes][:prescription_list]).to eq([])
        expect(result[:data][:attributes][:info_messages]).to eq([])
        expect(result[:data][:attributes][:errors]).to eq([
                                                            {
                                                              developer_message: 'Prescription expired',
                                                              prescription_id: '11111',
                                                              station_number: '556'
                                                            },
                                                            {
                                                              developer_message: 'Not refillable',
                                                              prescription_id: '22222',
                                                              station_number: '556'
                                                            },
                                                            {
                                                              developer_message: 'Invalid prescription',
                                                              prescription_id: '33333',
                                                              station_number: '556'
                                                            }
                                                          ])
      end
    end

    context 'with realistic API response format' do
      let(:resource) do
        {
          success: [
            {
              id: '15214174591',
              status: 'Already in Queue',
              station_number: '556'
            }
          ],
          failed: [
            {
              id: '15215488543',
              error: '^ER:Error:',
              station_number: '556'
            }
          ]
        }
      end

      it 'correctly processes realistic API response format' do
        serializer = described_class.new(id, resource)
        result = serializer.serializable_hash

        expect(result[:data][:type]).to eq(:PrescriptionRefills)
        expect(result[:data][:attributes][:failed_prescription_ids]).to eq(['15215488543'])
        expect(result[:data][:attributes][:failed_station_list]).to eq(['556'])
        expect(result[:data][:attributes][:successful_station_list]).to eq(['556'])
        expect(result[:data][:attributes][:last_updated_time]).to be_present
        expect(result[:data][:attributes][:prescription_list]).to eq([
                                                                       {
                                                                         id: '15214174591',
                                                                         status: 'Already in Queue',
                                                                         station_number: '556'
                                                                       }
                                                                     ])
        expect(result[:data][:attributes][:info_messages]).to eq([
                                                                   {
                                                                     prescription_id: '15214174591',
                                                                     message: 'Already in Queue',
                                                                     station_number: '556'
                                                                   }
                                                                 ])
        expect(result[:data][:attributes][:errors]).to eq([
                                                            {
                                                              developer_message: '^ER:Error:',
                                                              prescription_id: '15215488543',
                                                              station_number: '556'
                                                            }
                                                          ])
      end
    end

    context 'with mixed successes and failures' do
      let(:resource) do
        {
          success: [
            {
              id: '12345',
              status: 'submitted',
              station_number: '123'
            }
          ],
          failed: [
            {
              id: '67890',
              error: 'Not found',
              station_number: '456'
            }
          ]
        }
      end

      it 'correctly processes both successes and failures' do
        serializer = described_class.new(id, resource)
        result = serializer.serializable_hash

        expect(result[:data][:type]).to eq(:PrescriptionRefills)
        expect(result[:data][:attributes][:failed_prescription_ids]).to eq(['67890'])
        expect(result[:data][:attributes][:failed_station_list]).to eq(['456'])
        expect(result[:data][:attributes][:successful_station_list]).to eq(['123'])
        expect(result[:data][:attributes][:last_updated_time]).to be_present
        expect(result[:data][:attributes][:prescription_list]).to eq([
                                                                       {
                                                                         id: '12345',
                                                                         status: 'submitted',
                                                                         station_number: '123'
                                                                       }
                                                                     ])
        expect(result[:data][:attributes][:info_messages]).to eq([
                                                                   {
                                                                     prescription_id: '12345',
                                                                     message: 'submitted',
                                                                     station_number: '123'
                                                                   }
                                                                 ])
        expect(result[:data][:attributes][:errors]).to eq([
                                                            {
                                                              developer_message: 'Not found',
                                                              prescription_id: '67890',
                                                              station_number: '456'
                                                            }
                                                          ])
      end
    end
  end
end
