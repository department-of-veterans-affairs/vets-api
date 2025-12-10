# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/v2_status_mapper'

RSpec.describe UnifiedHealthData::Adapters::V2StatusMapper do
  # Create a test class that includes the module
  let(:test_class) do
    Class.new do
      include UnifiedHealthData::Adapters::V2StatusMapper
    end
  end

  let(:mapper) { test_class.new }

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
      end

      it 'is case-insensitive for compound statuses' do
        expect(mapper.map_to_v2_status('active: refill in process')).to eq('In progress')
        expect(mapper.map_to_v2_status('EXPIRED')).to eq('Inactive')
      end
    end

    context 'with edge cases' do
      it 'returns Status not available for nil' do
        expect(mapper.map_to_v2_status(nil)).to eq('Status not available')
      end

      it 'returns Status not available for blank string' do
        expect(mapper.map_to_v2_status('')).to eq('Status not available')
      end

      it 'returns Status not available for unmapped statuses' do
        expect(mapper.map_to_v2_status('Some Random Status')).to eq('Status not available')
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
    end

    it 'returns empty array for nil' do
      expect(mapper.original_statuses_for_v2_status(nil)).to eq([])
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
                                  "Expected '#{original}' to map to '#{expected}', got '#{rx.disp_status}'"
      end
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
  end
end
