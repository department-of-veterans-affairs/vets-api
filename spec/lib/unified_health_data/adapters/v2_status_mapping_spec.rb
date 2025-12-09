# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/v2_status_mapping'

RSpec.describe UnifiedHealthData::Adapters::V2StatusMapping do
  subject(:mapper) { test_class.new }

  let(:test_class) do
    Class.new do
      include UnifiedHealthData::Adapters::V2StatusMapping
    end
  end

  describe '#map_to_v2_status' do
    context 'Active status mappings' do
      it 'maps "Active" to "Active"' do
        expect(mapper.map_to_v2_status('Active')).to eq('Active')
      end

      it 'maps "Active: Parked" to "Active"' do
        expect(mapper.map_to_v2_status('Active: Parked')).to eq('Active')
      end

      it 'maps "Active: Non-VA" to "Active"' do
        expect(mapper.map_to_v2_status('Active: Non-VA')).to eq('Active')
      end

      it 'maps "Active with shipping info" to "Active"' do
        expect(mapper.map_to_v2_status('Active with shipping info')).to eq('Active')
      end
    end

    context 'In progress status mappings' do
      it 'maps "Active: Submitted" to "In progress"' do
        expect(mapper.map_to_v2_status('Active: Submitted')).to eq('In progress')
      end

      it 'maps "Active: Refill in Process" to "In progress"' do
        expect(mapper.map_to_v2_status('Active: Refill in Process')).to eq('In progress')
      end

      it 'maps "Pending New Prescription" to "In progress"' do
        expect(mapper.map_to_v2_status('Pending New Prescription')).to eq('In progress')
      end

      it 'maps "Pending Renewal" to "In progress"' do
        expect(mapper.map_to_v2_status('Pending Renewal')).to eq('In progress')
      end
    end

    context 'Inactive status mappings' do
      it 'maps "Expired" to "Inactive"' do
        expect(mapper.map_to_v2_status('Expired')).to eq('Inactive')
      end

      it 'maps "Discontinued" to "Inactive"' do
        expect(mapper.map_to_v2_status('Discontinued')).to eq('Inactive')
      end

      it 'maps "Active: On hold" to "Inactive"' do
        expect(mapper.map_to_v2_status('Active: On hold')).to eq('Inactive')
      end

      it 'maps "Active: On Hold" (uppercase) to "Inactive"' do
        expect(mapper.map_to_v2_status('Active: On Hold')).to eq('Inactive')
      end
    end

    context 'Transferred status mappings' do
      it 'maps "Transferred" to "Transferred"' do
        expect(mapper.map_to_v2_status('Transferred')).to eq('Transferred')
      end
    end

    context 'Unknown/fallback status mappings' do
      it 'maps "Unknown" to "Status not available"' do
        expect(mapper.map_to_v2_status('Unknown')).to eq('Status not available')
      end

      it 'maps unrecognized status to "Status not available"' do
        expect(mapper.map_to_v2_status('SomeRandomStatus')).to eq('Status not available')
      end

      it 'maps nil to "Status not available"' do
        expect(mapper.map_to_v2_status(nil)).to eq('Status not available')
      end

      it 'maps empty string to "Status not available"' do
        expect(mapper.map_to_v2_status('')).to eq('Status not available')
      end

      it 'maps whitespace-only string to "Status not available"' do
        expect(mapper.map_to_v2_status('   ')).to eq('Status not available')
      end
    end

    context 'case insensitivity' do
      it 'handles lowercase input' do
        expect(mapper.map_to_v2_status('active')).to eq('Active')
      end

      it 'handles uppercase input' do
        expect(mapper.map_to_v2_status('ACTIVE')).to eq('Active')
      end

      it 'handles mixed case input' do
        expect(mapper.map_to_v2_status('AcTiVe')).to eq('Active')
      end

      it 'handles lowercase "expired"' do
        expect(mapper.map_to_v2_status('expired')).to eq('Inactive')
      end

      it 'handles "DISCONTINUED" uppercase' do
        expect(mapper.map_to_v2_status('DISCONTINUED')).to eq('Inactive')
      end
    end
  end

  describe '#original_statuses_for_v2_status' do
    it 'returns Active statuses array' do
      result = mapper.original_statuses_for_v2_status('Active')

      expect(result).to include('Active', 'Active: Parked', 'Active: Non-VA', 'Active with shipping info')
    end

    it 'returns In progress statuses array' do
      result = mapper.original_statuses_for_v2_status('In progress')

      expect(result).to include('Active: Submitted', 'Active: Refill in Process', 'Pending New Prescription',
                                'Pending Renewal')
    end

    it 'returns Inactive statuses array' do
      result = mapper.original_statuses_for_v2_status('Inactive')

      expect(result).to include('Expired', 'Discontinued', 'Active: On hold', 'Active: On Hold')
    end

    it 'returns Transferred statuses array' do
      result = mapper.original_statuses_for_v2_status('Transferred')

      expect(result).to eq(['Transferred'])
    end

    it 'returns Unknown statuses array for Status not available' do
      result = mapper.original_statuses_for_v2_status('Status not available')

      expect(result).to eq(['Unknown'])
    end

    it 'returns empty array for nil input' do
      expect(mapper.original_statuses_for_v2_status(nil)).to eq([])
    end

    it 'returns empty array for unrecognized V2 status' do
      expect(mapper.original_statuses_for_v2_status('NotAV2Status')).to eq([])
    end
  end

  describe '#apply_v2_status_mapping' do
    context 'with hash-based prescription' do
      it 'maps disp_status to V2 status' do
        prescription = { disp_status: 'Active: Submitted', prescription_name: 'Test Med' }

        result = mapper.apply_v2_status_mapping(prescription)

        expect(result[:disp_status]).to eq('In progress')
        expect(result[:prescription_name]).to eq('Test Med')
      end

      it 'preserves other hash attributes' do
        prescription = {
          disp_status: 'Expired',
          prescription_id: '12345',
          refill_status: 'expired',
          facility_name: 'Test Facility'
        }

        result = mapper.apply_v2_status_mapping(prescription)

        expect(result[:disp_status]).to eq('Inactive')
        expect(result[:prescription_id]).to eq('12345')
        expect(result[:refill_status]).to eq('expired')
        expect(result[:facility_name]).to eq('Test Facility')
      end

      it 'returns prescription unchanged when disp_status is nil' do
        prescription = { disp_status: nil, prescription_name: 'Test Med' }

        result = mapper.apply_v2_status_mapping(prescription)

        expect(result[:disp_status]).to be_nil
      end

      it 'returns prescription unchanged when disp_status is empty' do
        prescription = { disp_status: '', prescription_name: 'Test Med' }

        result = mapper.apply_v2_status_mapping(prescription)

        expect(result[:disp_status]).to eq('')
      end
    end

    context 'with object-based prescription (OpenStruct)' do
      it 'maps disp_status to V2 status' do
        prescription = OpenStruct.new(disp_status: 'Active: Refill in Process', prescription_name: 'Test Med')

        result = mapper.apply_v2_status_mapping(prescription)

        expect(result.disp_status).to eq('In progress')
        expect(result.prescription_name).to eq('Test Med')
      end

      it 'preserves other object attributes' do
        prescription = OpenStruct.new(
          disp_status: 'Discontinued',
          prescription_id: '67890',
          refill_status: 'discontinued',
          facility_name: 'Another Facility'
        )

        result = mapper.apply_v2_status_mapping(prescription)

        expect(result.disp_status).to eq('Inactive')
        expect(result.prescription_id).to eq('67890')
        expect(result.refill_status).to eq('discontinued')
        expect(result.facility_name).to eq('Another Facility')
      end

      it 'returns prescription unchanged when disp_status is nil' do
        prescription = OpenStruct.new(disp_status: nil, prescription_name: 'Test Med')

        result = mapper.apply_v2_status_mapping(prescription)

        expect(result.disp_status).to be_nil
      end

      it 'returns prescription unchanged when disp_status is empty' do
        prescription = OpenStruct.new(disp_status: '', prescription_name: 'Test Med')

        result = mapper.apply_v2_status_mapping(prescription)

        expect(result.disp_status).to eq('')
      end
    end

    context 'with object that does not respond to disp_status=' do
      it 'returns the prescription unchanged' do
        prescription = double('ImmutablePrescription', disp_status: 'Active')
        allow(prescription).to receive(:respond_to?).with(:disp_status).and_return(true)
        allow(prescription).to receive(:respond_to?).with(:disp_status=).and_return(false)

        result = mapper.apply_v2_status_mapping(prescription)

        expect(result).to eq(prescription)
      end
    end
  end

  describe '#apply_v2_status_mapping_to_all' do
    it 'applies mapping to all prescriptions in collection' do
      prescriptions = [
        OpenStruct.new(disp_status: 'Active', prescription_id: '1'),
        OpenStruct.new(disp_status: 'Expired', prescription_id: '2'),
        OpenStruct.new(disp_status: 'Active: Submitted', prescription_id: '3'),
        OpenStruct.new(disp_status: 'Discontinued', prescription_id: '4')
      ]

      result = mapper.apply_v2_status_mapping_to_all(prescriptions)

      expect(result[0].disp_status).to eq('Active')
      expect(result[1].disp_status).to eq('Inactive')
      expect(result[2].disp_status).to eq('In progress')
      expect(result[3].disp_status).to eq('Inactive')
    end

    it 'handles mixed hash and object prescriptions' do
      prescriptions = [
        { disp_status: 'Active', prescription_id: '1' },
        OpenStruct.new(disp_status: 'Expired', prescription_id: '2')
      ]

      result = mapper.apply_v2_status_mapping_to_all(prescriptions)

      expect(result[0][:disp_status]).to eq('Active')
      expect(result[1].disp_status).to eq('Inactive')
    end

    it 'returns empty array for empty input' do
      result = mapper.apply_v2_status_mapping_to_all([])

      expect(result).to eq([])
    end

    it 'handles prescriptions with nil disp_status' do
      prescriptions = [
        OpenStruct.new(disp_status: nil, prescription_id: '1'),
        OpenStruct.new(disp_status: 'Active', prescription_id: '2')
      ]

      result = mapper.apply_v2_status_mapping_to_all(prescriptions)

      expect(result[0].disp_status).to be_nil
      expect(result[1].disp_status).to eq('Active')
    end

    it 'handles prescriptions with unrecognized statuses' do
      prescriptions = [
        OpenStruct.new(disp_status: 'UnknownStatus', prescription_id: '1'),
        OpenStruct.new(disp_status: 'Active', prescription_id: '2')
      ]

      result = mapper.apply_v2_status_mapping_to_all(prescriptions)

      expect(result[0].disp_status).to eq('Status not available')
      expect(result[1].disp_status).to eq('Active')
    end
  end

  describe 'V2_STATUS_GROUPS constant' do
    it 'contains all expected V2 status keys' do
      expected_keys = ['Active', 'In progress', 'Inactive', 'Transferred', 'Status not available']

      expect(described_class::V2_STATUS_GROUPS.keys).to match_array(expected_keys)
    end

    it 'is frozen to prevent modification' do
      expect(described_class::V2_STATUS_GROUPS).to be_frozen
    end
  end

  describe 'ORIGINAL_TO_V2_STATUS_MAPPING constant' do
    it 'contains lowercase keys for case-insensitive matching' do
      described_class::ORIGINAL_TO_V2_STATUS_MAPPING.each_key do |key|
        expect(key).to eq(key.downcase), "Expected key '#{key}' to be lowercase"
      end
    end

    it 'is frozen to prevent modification' do
      expect(described_class::ORIGINAL_TO_V2_STATUS_MAPPING).to be_frozen
    end

    it 'maps all original statuses to correct V2 statuses' do
      mapping = described_class::ORIGINAL_TO_V2_STATUS_MAPPING

      # Active mappings
      expect(mapping['active']).to eq('Active')
      expect(mapping['active: parked']).to eq('Active')
      expect(mapping['active: non-va']).to eq('Active')

      # In progress mappings
      expect(mapping['active: submitted']).to eq('In progress')
      expect(mapping['active: refill in process']).to eq('In progress')
      expect(mapping['pending new prescription']).to eq('In progress')

      # Inactive mappings
      expect(mapping['expired']).to eq('Inactive')
      expect(mapping['discontinued']).to eq('Inactive')
      expect(mapping['active: on hold']).to eq('Inactive')

      # Transferred mappings
      expect(mapping['transferred']).to eq('Transferred')

      # Status not available mappings
      expect(mapping['unknown']).to eq('Status not available')
    end
  end
end
