# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/v2_status_mapper'

RSpec.describe UnifiedHealthData::Adapters::V2StatusMapper do
  # Create a test class that includes the module
  let(:test_class) { Class.new { include UnifiedHealthData::Adapters::V2StatusMapper }.new }

  describe 'V2_STATUS_GROUPS constant' do
    it 'defines correct status groupings' do
      expected_groups = {
        'Active' => ['Active', 'Active: Parked', 'Active: Non-VA'],
        'In progress' => ['Active: Submitted', 'Active: Refill in Process'],
        'Inactive' => ['Expired', 'Discontinued', 'Active: On hold'],
        'Transferred' => ['Transferred'],
        'Status not available' => ['Unknown']
      }

      expect(described_class::V2_STATUS_GROUPS).to eq(expected_groups)
    end

    it 'has frozen status groups' do
      expect(described_class::V2_STATUS_GROUPS).to be_frozen
    end

    it 'has frozen arrays within status groups' do
      described_class::V2_STATUS_GROUPS.each_value do |statuses|
        expect(statuses).to be_frozen
      end
    end

    it 'contains all expected V2 status keys' do
      expected_keys = ['Active', 'In progress', 'Inactive', 'Transferred', 'Status not available']
      expect(described_class::V2_STATUS_GROUPS.keys).to match_array(expected_keys)
    end

    it 'contains exactly 10 original statuses across all groups' do
      total_statuses = described_class::V2_STATUS_GROUPS.values.flatten
      expect(total_statuses.length).to eq(10)
    end
  end

  describe 'ORIGINAL_TO_V2_STATUS_MAPPING constant' do
    it 'generates correct case-insensitive mappings' do
      mapping = described_class::ORIGINAL_TO_V2_STATUS_MAPPING

      expect(mapping.keys).to all(satisfy { |k| k == k.downcase })
    end

    it 'maps Active statuses correctly' do
      mapping = described_class::ORIGINAL_TO_V2_STATUS_MAPPING

      expect(mapping['active']).to eq('Active')
      expect(mapping['active: parked']).to eq('Active')
      expect(mapping['active: non-va']).to eq('Active')
    end

    it 'maps In progress statuses correctly' do
      mapping = described_class::ORIGINAL_TO_V2_STATUS_MAPPING

      expect(mapping['active: submitted']).to eq('In progress')
      expect(mapping['active: refill in process']).to eq('In progress')
    end

    it 'maps Inactive statuses correctly' do
      mapping = described_class::ORIGINAL_TO_V2_STATUS_MAPPING

      expect(mapping['expired']).to eq('Inactive')
      expect(mapping['discontinued']).to eq('Inactive')
      expect(mapping['active: on hold']).to eq('Inactive')
    end

    it 'maps Transferred status correctly' do
      mapping = described_class::ORIGINAL_TO_V2_STATUS_MAPPING

      expect(mapping['transferred']).to eq('Transferred')
    end

    it 'maps Unknown status correctly' do
      mapping = described_class::ORIGINAL_TO_V2_STATUS_MAPPING

      expect(mapping['unknown']).to eq('Status not available')
    end

    it 'is frozen' do
      expect(described_class::ORIGINAL_TO_V2_STATUS_MAPPING).to be_frozen
    end

    it 'contains exactly 10 mappings' do
      expect(described_class::ORIGINAL_TO_V2_STATUS_MAPPING.length).to eq(10)
    end

    it 'has all lowercase keys' do
      described_class::ORIGINAL_TO_V2_STATUS_MAPPING.each_key do |key|
        expect(key).to eq(key.downcase), "Expected key '#{key}' to be lowercase"
      end
    end
  end

  describe '#map_to_v2_status' do
    context 'with Active statuses' do
      it 'maps Active to Active' do
        expect(test_class.map_to_v2_status('Active')).to eq('Active')
      end

      it 'maps Active: Parked to Active' do
        expect(test_class.map_to_v2_status('Active: Parked')).to eq('Active')
      end

      it 'maps Active: Non-VA to Active' do
        expect(test_class.map_to_v2_status('Active: Non-VA')).to eq('Active')
      end
    end

    context 'with In progress statuses' do
      it 'maps Active: Submitted to In progress' do
        expect(test_class.map_to_v2_status('Active: Submitted')).to eq('In progress')
      end

      it 'maps Active: Refill in Process to In progress' do
        expect(test_class.map_to_v2_status('Active: Refill in Process')).to eq('In progress')
      end
    end

    context 'with Inactive statuses' do
      it 'maps Expired to Inactive' do
        expect(test_class.map_to_v2_status('Expired')).to eq('Inactive')
      end

      it 'maps Discontinued to Inactive' do
        expect(test_class.map_to_v2_status('Discontinued')).to eq('Inactive')
      end

      it 'maps Active: On hold to Inactive' do
        expect(test_class.map_to_v2_status('Active: On hold')).to eq('Inactive')
      end
    end

    context 'with other statuses' do
      it 'maps Transferred to Transferred' do
        expect(test_class.map_to_v2_status('Transferred')).to eq('Transferred')
      end

      it 'maps Unknown to Status not available' do
        expect(test_class.map_to_v2_status('Unknown')).to eq('Status not available')
      end
    end

    context 'with case variations' do
      it 'is case-insensitive for Active' do
        expect(test_class.map_to_v2_status('active')).to eq('Active')
        expect(test_class.map_to_v2_status('ACTIVE')).to eq('Active')
      end

      it 'is case-insensitive for compound statuses' do
        expect(test_class.map_to_v2_status('active: refill in process')).to eq('In progress')
        expect(test_class.map_to_v2_status('ACTIVE: REFILL IN PROCESS')).to eq('In progress')
      end
    end

    context 'with edge cases' do
      it 'returns Status not available for nil' do
        expect(test_class.map_to_v2_status(nil)).to eq('Status not available')
      end

      it 'returns Status not available for blank string' do
        expect(test_class.map_to_v2_status('')).to eq('Status not available')
      end

      it 'returns Status not available for unmapped statuses' do
        expect(test_class.map_to_v2_status('SomeRandomStatus')).to eq('Status not available')
      end
    end
  end

  describe '#original_statuses_for_v2_status' do
    it 'returns original statuses for Active' do
      expect(test_class.original_statuses_for_v2_status('Active'))
        .to contain_exactly('Active', 'Active: Parked', 'Active: Non-VA')
    end

    it 'returns original statuses for In progress' do
      expect(test_class.original_statuses_for_v2_status('In progress'))
        .to contain_exactly('Active: Submitted', 'Active: Refill in Process')
    end

    it 'returns original statuses for Inactive' do
      expect(test_class.original_statuses_for_v2_status('Inactive'))
        .to contain_exactly('Expired', 'Discontinued', 'Active: On hold')
    end

    it 'returns original statuses for Transferred' do
      expect(test_class.original_statuses_for_v2_status('Transferred'))
        .to contain_exactly('Transferred')
    end

    it 'returns original statuses for Status not available' do
      expect(test_class.original_statuses_for_v2_status('Status not available'))
        .to contain_exactly('Unknown')
    end

    it 'returns empty array for unknown V2 status' do
      expect(test_class.original_statuses_for_v2_status('NonExistentStatus')).to eq([])
    end

    it 'returns empty array for nil' do
      expect(test_class.original_statuses_for_v2_status(nil)).to eq([])
    end
  end

  describe '#apply_v2_status_mapping' do
    context 'with OpenStruct prescription' do
      let(:prescription) { OpenStruct.new(disp_status: 'Active: Refill in Process') }

      it 'maps disp_status to V2 status' do
        result = test_class.apply_v2_status_mapping(prescription)
        expect(result.disp_status).to eq('In progress')
      end

      it 'returns the same prescription object (mutates in place)' do
        result = test_class.apply_v2_status_mapping(prescription)
        expect(result).to eq(prescription)
      end
    end

    context 'with Hash prescription' do
      let(:prescription) { { disp_status: 'Active: Refill in Process' } }

      it 'maps disp_status to V2 status' do
        result = test_class.apply_v2_status_mapping(prescription)
        expect(result[:disp_status]).to eq('In progress')
      end

      it 'returns the same hash object (mutates in place)' do
        result = test_class.apply_v2_status_mapping(prescription)
        expect(result).to eq(prescription)
      end
    end

    context 'with nil disp_status' do
      it 'handles OpenStruct with nil disp_status' do
        prescription = OpenStruct.new(disp_status: nil)
        result = test_class.apply_v2_status_mapping(prescription)
        expect(result.disp_status).to be_nil
      end

      it 'handles Hash with nil disp_status' do
        prescription = { disp_status: nil }
        result = test_class.apply_v2_status_mapping(prescription)
        expect(result[:disp_status]).to be_nil
      end
    end

    it 'maps all status types correctly for OpenStruct' do
      status_mappings = {
        'Active' => 'Active',
        'Active: Parked' => 'Active',
        'Active: Non-VA' => 'Active',
        'Active: Submitted' => 'In progress',
        'Active: Refill in Process' => 'In progress',
        'Expired' => 'Inactive',
        'Discontinued' => 'Inactive',
        'Active: On hold' => 'Inactive',
        'Transferred' => 'Transferred',
        'Unknown' => 'Status not available'
      }

      status_mappings.each do |original, expected|
        prescription = OpenStruct.new(disp_status: original)
        test_class.apply_v2_status_mapping(prescription)
        expect(prescription.disp_status).to eq(expected)
      end
    end

    it 'maps all status types correctly for Hash' do
      status_mappings = {
        'Active' => 'Active',
        'Active: Parked' => 'Active',
        'Active: Non-VA' => 'Active',
        'Active: Submitted' => 'In progress',
        'Active: Refill in Process' => 'In progress',
        'Expired' => 'Inactive',
        'Discontinued' => 'Inactive',
        'Active: On hold' => 'Inactive',
        'Transferred' => 'Transferred',
        'Unknown' => 'Status not available'
      }

      status_mappings.each do |original, expected|
        prescription = { disp_status: original }
        test_class.apply_v2_status_mapping(prescription)
        expect(prescription[:disp_status]).to eq(expected)
      end
    end
  end

  describe '#apply_v2_status_mapping_to_collection' do
    context 'with mixed OpenStruct collection' do
      let(:prescriptions) do
        [
          OpenStruct.new(disp_status: 'Active'),
          OpenStruct.new(disp_status: 'Active: Refill in Process'),
          OpenStruct.new(disp_status: 'Expired'),
          OpenStruct.new(disp_status: 'Discontinued'),
          OpenStruct.new(disp_status: 'Unknown')
        ]
      end

      it 'maps all prescriptions to V2 statuses' do
        result = test_class.apply_v2_status_mapping_to_collection(prescriptions)

        expect(result[0].disp_status).to eq('Active')
        expect(result[1].disp_status).to eq('In progress')
        expect(result[2].disp_status).to eq('Inactive')
        expect(result[3].disp_status).to eq('Inactive')
        expect(result[4].disp_status).to eq('Status not available')
      end
    end

    context 'with mixed Hash collection' do
      let(:prescriptions) do
        [
          { disp_status: 'Active' },
          { disp_status: 'Active: Refill in Process' },
          { disp_status: 'Expired' }
        ]
      end

      it 'maps all hash prescriptions to V2 statuses' do
        result = test_class.apply_v2_status_mapping_to_collection(prescriptions)

        expect(result[0][:disp_status]).to eq('Active')
        expect(result[1][:disp_status]).to eq('In progress')
        expect(result[2][:disp_status]).to eq('Inactive')
      end
    end

    it 'handles empty array' do
      result = test_class.apply_v2_status_mapping_to_collection([])
      expect(result).to eq([])
    end

    it 'handles nil' do
      result = test_class.apply_v2_status_mapping_to_collection(nil)
      expect(result).to be_nil
    end
  end

  describe 'constants' do
    it 'defines V2_STATUS_GROUPS' do
      expect(UnifiedHealthData::Adapters::V2StatusMapper::V2_STATUS_GROUPS).to be_a(Hash)
      expect(UnifiedHealthData::Adapters::V2StatusMapper::V2_STATUS_GROUPS.keys).to contain_exactly(
        'Active', 'In progress', 'Inactive', 'Transferred', 'Status not available'
      )
    end

    it 'defines ORIGINAL_TO_V2_STATUS_MAPPING' do
      expect(UnifiedHealthData::Adapters::V2StatusMapper::ORIGINAL_TO_V2_STATUS_MAPPING).to be_a(Hash)
      expect(UnifiedHealthData::Adapters::V2StatusMapper::ORIGINAL_TO_V2_STATUS_MAPPING['active']).to eq('Active')
      expect(UnifiedHealthData::Adapters::V2StatusMapper::ORIGINAL_TO_V2_STATUS_MAPPING['expired']).to eq('Inactive')
    end

    it 'has frozen constants' do
      expect(UnifiedHealthData::Adapters::V2StatusMapper::V2_STATUS_GROUPS).to be_frozen
      expect(UnifiedHealthData::Adapters::V2StatusMapper::ORIGINAL_TO_V2_STATUS_MAPPING).to be_frozen
    end
  end
end
