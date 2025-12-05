# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/v2_status_mapper'

RSpec.describe UnifiedHealthData::Adapters::V2StatusMapper do
  # Create a test class that includes the module
  let(:mapper_class) do
    Class.new do
      include UnifiedHealthData::Adapters::V2StatusMapper
    end
  end
  let(:mapper) { mapper_class.new }

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
        expect(mapper.map_to_v2_status('Active')).to eq('Active')
      end

      it 'maps Active: Parked to Active' do
        expect(mapper.map_to_v2_status('Active: Parked')).to eq('Active')
      end

      it 'maps Active: Non-VA to Active' do
        expect(mapper.map_to_v2_status('Active: Non-VA')).to eq('Active')
      end
    end

    context 'with In progress statuses' do
      it 'maps Active: Submitted to In progress' do
        expect(mapper.map_to_v2_status('Active: Submitted')).to eq('In progress')
      end

      it 'maps Active: Refill in Process to In progress' do
        expect(mapper.map_to_v2_status('Active: Refill in Process')).to eq('In progress')
      end
    end

    context 'with Inactive statuses' do
      it 'maps Expired to Inactive' do
        expect(mapper.map_to_v2_status('Expired')).to eq('Inactive')
      end

      it 'maps Discontinued to Inactive' do
        expect(mapper.map_to_v2_status('Discontinued')).to eq('Inactive')
      end

      it 'maps Active: On hold to Inactive' do
        expect(mapper.map_to_v2_status('Active: On hold')).to eq('Inactive')
      end
    end

    context 'with other statuses' do
      it 'maps Transferred to Transferred' do
        expect(mapper.map_to_v2_status('Transferred')).to eq('Transferred')
      end

      it 'maps Unknown to Status not available' do
        expect(mapper.map_to_v2_status('Unknown')).to eq('Status not available')
      end
    end

    context 'with case variations' do
      it 'is case-insensitive for Active' do
        expect(mapper.map_to_v2_status('ACTIVE')).to eq('Active')
        expect(mapper.map_to_v2_status('active')).to eq('Active')
        expect(mapper.map_to_v2_status('AcTiVe')).to eq('Active')
      end

      it 'is case-insensitive for compound statuses' do
        expect(mapper.map_to_v2_status('active: refill in process')).to eq('In progress')
        expect(mapper.map_to_v2_status('ACTIVE: REFILL IN PROCESS')).to eq('In progress')
        expect(mapper.map_to_v2_status('EXPIRED')).to eq('Inactive')
      end

      it 'is case-insensitive for Active: Parked' do
        expect(mapper.map_to_v2_status('ACTIVE: PARKED')).to eq('Active')
        expect(mapper.map_to_v2_status('active: parked')).to eq('Active')
      end

      it 'is case-insensitive for Active: Non-VA' do
        expect(mapper.map_to_v2_status('ACTIVE: NON-VA')).to eq('Active')
        expect(mapper.map_to_v2_status('active: non-va')).to eq('Active')
      end

      it 'is case-insensitive for Active: Submitted' do
        expect(mapper.map_to_v2_status('ACTIVE: SUBMITTED')).to eq('In progress')
        expect(mapper.map_to_v2_status('active: submitted')).to eq('In progress')
      end

      it 'is case-insensitive for Active: On hold' do
        expect(mapper.map_to_v2_status('ACTIVE: ON HOLD')).to eq('Inactive')
        expect(mapper.map_to_v2_status('active: on hold')).to eq('Inactive')
      end

      it 'is case-insensitive for Discontinued' do
        expect(mapper.map_to_v2_status('DISCONTINUED')).to eq('Inactive')
        expect(mapper.map_to_v2_status('discontinued')).to eq('Inactive')
      end

      it 'is case-insensitive for Transferred' do
        expect(mapper.map_to_v2_status('TRANSFERRED')).to eq('Transferred')
        expect(mapper.map_to_v2_status('transferred')).to eq('Transferred')
      end

      it 'is case-insensitive for Unknown' do
        expect(mapper.map_to_v2_status('UNKNOWN')).to eq('Status not available')
        expect(mapper.map_to_v2_status('unknown')).to eq('Status not available')
      end
    end

    context 'with edge cases' do
      it 'returns Status not available for nil' do
        expect(mapper.map_to_v2_status(nil)).to eq('Status not available')
      end

      it 'returns Status not available for blank string' do
        expect(mapper.map_to_v2_status('')).to eq('Status not available')
      end

      it 'returns Status not available for whitespace only' do
        expect(mapper.map_to_v2_status('   ')).to eq('Status not available')
      end

      it 'returns Status not available for unmapped statuses' do
        expect(mapper.map_to_v2_status('Random Status')).to eq('Status not available')
        expect(mapper.map_to_v2_status('Some New Status')).to eq('Status not available')
      end

      it 'returns Status not available for partially matching statuses' do
        expect(mapper.map_to_v2_status('Active:')).to eq('Status not available')
        expect(mapper.map_to_v2_status('Active: ')).to eq('Status not available')
        expect(mapper.map_to_v2_status('Active: Unknown')).to eq('Status not available')
      end

      it 'returns Status not available for status with extra whitespace' do
        expect(mapper.map_to_v2_status('  Active  ')).to eq('Status not available')
      end
    end
  end

  describe '#original_statuses_for_v2_status' do
    it 'returns original statuses for Active' do
      expect(mapper.original_statuses_for_v2_status('Active')).to eq(
        ['Active', 'Active: Parked', 'Active: Non-VA']
      )
    end

    it 'returns original statuses for In progress' do
      expect(mapper.original_statuses_for_v2_status('In progress')).to eq(
        ['Active: Submitted', 'Active: Refill in Process']
      )
    end

    it 'returns original statuses for Inactive' do
      expect(mapper.original_statuses_for_v2_status('Inactive')).to eq(
        ['Expired', 'Discontinued', 'Active: On hold']
      )
    end

    it 'returns original statuses for Transferred' do
      expect(mapper.original_statuses_for_v2_status('Transferred')).to eq(['Transferred'])
    end

    it 'returns original statuses for Status not available' do
      expect(mapper.original_statuses_for_v2_status('Status not available')).to eq(['Unknown'])
    end

    it 'returns empty array for unknown V2 status' do
      expect(mapper.original_statuses_for_v2_status('Unknown V2 Status')).to eq([])
      expect(mapper.original_statuses_for_v2_status('Random')).to eq([])
    end

    it 'returns empty array for nil' do
      expect(mapper.original_statuses_for_v2_status(nil)).to eq([])
    end

    it 'returns empty array for blank string' do
      expect(mapper.original_statuses_for_v2_status('')).to eq([])
    end

    it 'is case-sensitive for V2 status lookup' do
      # V2 status names are expected to be exact matches
      expect(mapper.original_statuses_for_v2_status('active')).to eq([])
      expect(mapper.original_statuses_for_v2_status('ACTIVE')).to eq([])
      expect(mapper.original_statuses_for_v2_status('in progress')).to eq([])
      expect(mapper.original_statuses_for_v2_status('IN PROGRESS')).to eq([])
    end
  end

  describe '#apply_v2_status_mapping' do
    let(:prescription) { OpenStruct.new(disp_status: 'Active: Refill in Process') }

    it 'maps disp_status to V2 status' do
      result = mapper.apply_v2_status_mapping(prescription)
      expect(result.disp_status).to eq('In progress')
    end

    it 'returns the same prescription object (mutates in place)' do
      result = mapper.apply_v2_status_mapping(prescription)
      expect(result).to be(prescription)
    end

    it 'handles nil disp_status by not changing it' do
      prescription.disp_status = nil
      result = mapper.apply_v2_status_mapping(prescription)
      expect(result.disp_status).to be_nil
    end

    it 'handles blank disp_status by not changing it' do
      prescription.disp_status = ''
      result = mapper.apply_v2_status_mapping(prescription)
      expect(result.disp_status).to eq('')
    end

    it 'handles prescription without disp_status method' do
      plain_object = Object.new
      result = mapper.apply_v2_status_mapping(plain_object)
      expect(result).to be(plain_object)
    end

    it 'handles prescription without disp_status= method' do
      read_only_object = OpenStruct.new
      def read_only_object.disp_status
        'Active'
      end
      result = mapper.apply_v2_status_mapping(read_only_object)
      expect(result).to be(read_only_object)
    end

    it 'maps all status types correctly' do
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
        rx = OpenStruct.new(disp_status: original)
        mapper.apply_v2_status_mapping(rx)
        expect(rx.disp_status).to eq(expected),
                                  "Expected '#{original}' to map to '#{expected}', " \
                                  "got '#{rx.disp_status}'"
      end
    end

    it 'maps unmapped statuses to Status not available' do
      prescription.disp_status = 'Some Random Status'
      result = mapper.apply_v2_status_mapping(prescription)
      expect(result.disp_status).to eq('Status not available')
    end

    it 'handles prescription with symbol-based attribute access' do
      hash_like_prescription = { disp_status: 'Active: Refill in Process' }
      # This should not raise an error even though hash doesn't respond to disp_status=
      result = mapper.apply_v2_status_mapping(hash_like_prescription)
      expect(result).to eq(hash_like_prescription)
    end
  end

  describe '#apply_v2_status_mapping_to_collection' do
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
      result = mapper.apply_v2_status_mapping_to_collection(prescriptions)

      expect(result[0].disp_status).to eq('Active')
      expect(result[1].disp_status).to eq('In progress')
      expect(result[2].disp_status).to eq('Inactive')
      expect(result[3].disp_status).to eq('Inactive')
      expect(result[4].disp_status).to eq('Status not available')
    end

    it 'returns an array of the same length' do
      result = mapper.apply_v2_status_mapping_to_collection(prescriptions)
      expect(result.length).to eq(prescriptions.length)
    end

    it 'handles empty array' do
      result = mapper.apply_v2_status_mapping_to_collection([])
      expect(result).to eq([])
    end

    it 'mutates original prescription objects' do
      original_first = prescriptions.first
      mapper.apply_v2_status_mapping_to_collection(prescriptions)

      expect(original_first.disp_status).to eq('Active')
    end

    it 'handles nil values in collection' do
      prescriptions_with_nil = [
        OpenStruct.new(disp_status: 'Active'),
        nil,
        OpenStruct.new(disp_status: 'Expired')
      ]

      # This should handle nil gracefully
      result = mapper.apply_v2_status_mapping_to_collection(prescriptions_with_nil)
      expect(result[0].disp_status).to eq('Active')
      expect(result[1]).to be_nil
      expect(result[2].disp_status).to eq('Inactive')
    end

    it 'handles mixed objects in collection' do
      mixed_collection = [
        OpenStruct.new(disp_status: 'Active'),
        { disp_status: 'Expired' }, # Hash - should be passed through unchanged
        OpenStruct.new(disp_status: 'Discontinued')
      ]

      result = mapper.apply_v2_status_mapping_to_collection(mixed_collection)
      expect(result[0].disp_status).to eq('Active')
      expect(result[1][:disp_status]).to eq('Expired') # Hash unchanged
      expect(result[2].disp_status).to eq('Inactive')
    end

    it 'preserves other attributes on prescription objects' do
      prescriptions_with_attributes = [
        OpenStruct.new(
          disp_status: 'Active',
          prescription_id: '12345',
          prescription_name: 'Test Med',
          refill_remaining: 3
        )
      ]

      result = mapper.apply_v2_status_mapping_to_collection(prescriptions_with_attributes)

      expect(result[0].disp_status).to eq('Active')
      expect(result[0].prescription_id).to eq('12345')
      expect(result[0].prescription_name).to eq('Test Med')
      expect(result[0].refill_remaining).to eq(3)
    end

    it 'handles large collections efficiently' do
      large_collection = Array.new(1000) do
        OpenStruct.new(disp_status: %w[Active Expired Discontinued Unknown].sample)
      end

      result = mapper.apply_v2_status_mapping_to_collection(large_collection)
      expect(result.length).to eq(1000)
      expect(result).to all(satisfy { |rx| rx.disp_status.present? })
    end
  end

  describe 'bidirectional mapping consistency' do
    it 'maps all original statuses to a V2 status and back' do
      all_original_statuses = described_class::V2_STATUS_GROUPS.values.flatten

      all_original_statuses.each do |original_status|
        v2_status = mapper.map_to_v2_status(original_status)
        original_statuses = mapper.original_statuses_for_v2_status(v2_status)

        expect(original_statuses).to include(original_status),
                                     "Expected V2 status '#{v2_status}' to map back to include " \
                                     "'#{original_status}', got #{original_statuses}"
      end
    end

    it 'ensures no original status appears in multiple V2 groups' do
      all_statuses = described_class::V2_STATUS_GROUPS.values.flatten
      expect(all_statuses.uniq.length).to eq(all_statuses.length),
                                          'Found duplicate status in V2_STATUS_GROUPS'
    end
  end

  describe 'module inclusion' do
    it 'can be included in any class' do
      test_class = Class.new do
        include UnifiedHealthData::Adapters::V2StatusMapper
      end

      instance = test_class.new
      expect(instance).to respond_to(:map_to_v2_status)
      expect(instance).to respond_to(:original_statuses_for_v2_status)
      expect(instance).to respond_to(:apply_v2_status_mapping)
      expect(instance).to respond_to(:apply_v2_status_mapping_to_collection)
    end

    it 'provides access to constants through included class' do
      test_class = Class.new do
        include UnifiedHealthData::Adapters::V2StatusMapper
      end

      expect(test_class::V2_STATUS_GROUPS).to eq(described_class::V2_STATUS_GROUPS)
      expect(test_class::ORIGINAL_TO_V2_STATUS_MAPPING).to eq(described_class::ORIGINAL_TO_V2_STATUS_MAPPING)
    end
  end
end
