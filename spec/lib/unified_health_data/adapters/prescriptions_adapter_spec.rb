# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/prescriptions_adapter'

RSpec.describe UnifiedHealthData::Adapters::PrescriptionsAdapter do
  subject(:adapter) { described_class.new(use_v2_statuses:) }

  let(:use_v2_statuses) { false }

  describe '#combine_prescriptions' do
    let(:oracle_resource) do
      double('FHIR::MedicationRequest',
             id: '12345',
             status: 'active',
             medicationCodeableConcept: double(text: 'Test Med'))
    end

    let(:vista_prescription) do
      OpenStruct.new(
        prescription_id: '67890',
        disp_status: 'Expired',
        prescription_name: 'VistA Med'
      )
    end

    context 'with use_v2_statuses: false' do
      let(:use_v2_statuses) { false }

      it 'preserves original status values' do
        allow_any_instance_of(UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter)
          .to receive(:parse).and_return(OpenStruct.new(disp_status: 'Active'))

        result = adapter.combine_prescriptions(
          oracle_resources: [oracle_resource],
          vista_prescriptions: [vista_prescription]
        )

        expect(result[0].disp_status).to eq('Active')
        expect(result[1].disp_status).to eq('Expired')
      end
    end

    context 'with use_v2_statuses: true' do
      let(:use_v2_statuses) { true }

      it 'applies V2 status mapping to all prescriptions' do
        allow_any_instance_of(UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter)
          .to receive(:parse).and_return(OpenStruct.new(disp_status: 'Active: Refill in Process'))

        result = adapter.combine_prescriptions(
          oracle_resources: [oracle_resource],
          vista_prescriptions: [vista_prescription]
        )

        expect(result[0].disp_status).to eq('In progress')
        expect(result[1].disp_status).to eq('Inactive')
      end

      it 'applies V2 status mapping consistently to combined prescriptions' do
        # Test that both Oracle and VistA prescriptions get mapped in a single pass
        oracle_rx = OpenStruct.new(disp_status: 'Active: Submitted')
        vista_rx = OpenStruct.new(
          prescription_id: '67890',
          disp_status: 'Discontinued',
          prescription_name: 'VistA Med'
        )

        allow_any_instance_of(UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter)
          .to receive(:parse).and_return(oracle_rx)

        result = adapter.combine_prescriptions(
          oracle_resources: [oracle_resource],
          vista_prescriptions: [vista_rx]
        )

        # Verify all prescriptions have V2 statuses (proves mapping was applied)
        result.each do |rx|
          expect(rx.disp_status).to be_in(
            ['Active', 'In progress', 'Inactive', 'Transferred', 'Status not available']
          )
        end

        # Verify specific mappings
        expect(result[0].disp_status).to eq('In progress')  # Active: Submitted → In progress
        expect(result[1].disp_status).to eq('Inactive')     # Discontinued → Inactive
      end
    end
  end

  describe '#map_v2_filters_to_original' do
    it 'maps V2 Active filter to original statuses' do
      result = adapter.map_v2_filters_to_original(['Active'])

      expect(result).to contain_exactly('active', 'active: parked', 'active: non-va')
    end

    it 'maps V2 Inactive filter to original statuses' do
      result = adapter.map_v2_filters_to_original(['Inactive'])

      expect(result).to contain_exactly('expired', 'discontinued', 'active: on hold')
    end

    it 'handles case-insensitive filters' do
      result = adapter.map_v2_filters_to_original(['inactive'])

      expect(result).to contain_exactly('expired', 'discontinued', 'active: on hold')
    end

    it 'handles multiple filters' do
      result = adapter.map_v2_filters_to_original(['Active', 'In progress'])

      expect(result).to contain_exactly(
        'active', 'active: parked', 'active: non-va',
        'active: submitted', 'active: refill in process'
      )
    end

    it 'maps V2 "In progress" filter to original statuses' do
      result = adapter.map_v2_filters_to_original(['In progress'])

      expect(result).to contain_exactly('active: submitted', 'active: refill in process')
    end

    it 'maps V2 "Transferred" filter to original status' do
      result = adapter.map_v2_filters_to_original(['Transferred'])

      expect(result).to contain_exactly('transferred')
    end

    it 'maps V2 "Status not available" filter to original status' do
      result = adapter.map_v2_filters_to_original(['Status not available'])

      expect(result).to contain_exactly('unknown')
    end

    it 'returns original filter when no V2 mapping exists' do
      result = adapter.map_v2_filters_to_original(['SomeUnknownStatus'])

      expect(result).to contain_exactly('someunknownstatus')
    end

    it 'handles empty filter array' do
      result = adapter.map_v2_filters_to_original([])

      expect(result).to be_empty
    end

    it 'handles mixed case V2 status filters' do
      result = adapter.map_v2_filters_to_original(['IN PROGRESS'])

      expect(result).to contain_exactly('active: submitted', 'active: refill in process')
    end

    it 'handles filters with extra whitespace' do
      result = adapter.map_v2_filters_to_original(['  Active  '])

      expect(result).to contain_exactly('active', 'active: parked', 'active: non-va')
    end
  end

  describe '#combine_prescriptions edge cases' do
    context 'with empty inputs' do
      it 'handles empty oracle_resources' do
        result = adapter.combine_prescriptions(
          oracle_resources: [],
          vista_prescriptions: [vista_prescription]
        )

        expect(result.length).to eq(1)
        expect(result[0].disp_status).to eq('Expired')
      end

      it 'handles empty vista_prescriptions' do
        allow_any_instance_of(UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter)
          .to receive(:parse).and_return(OpenStruct.new(disp_status: 'Active'))

        result = adapter.combine_prescriptions(
          oracle_resources: [oracle_resource],
          vista_prescriptions: []
        )

        expect(result.length).to eq(1)
        expect(result[0].disp_status).to eq('Active')
      end

      it 'handles both inputs empty' do
        result = adapter.combine_prescriptions(
          oracle_resources: [],
          vista_prescriptions: []
        )

        expect(result).to be_empty
      end
    end

    context 'with nil disp_status' do
      let(:use_v2_statuses) { true }

      it 'handles prescription with nil disp_status' do
        allow_any_instance_of(UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter)
          .to receive(:parse).and_return(OpenStruct.new(disp_status: nil))

        result = adapter.combine_prescriptions(
          oracle_resources: [oracle_resource],
          vista_prescriptions: []
        )

        # Should not raise error, status remains nil or gets default
        expect(result.length).to eq(1)
      end
    end

    context 'with unmapped status' do
      let(:use_v2_statuses) { true }

      it 'maps unmapped status to "Status not available"' do
        vista_rx_with_unknown = OpenStruct.new(
          prescription_id: '99999',
          disp_status: 'SomeRandomStatus',
          prescription_name: 'Unknown Med'
        )

        result = adapter.combine_prescriptions(
          oracle_resources: [],
          vista_prescriptions: [vista_rx_with_unknown]
        )

        expect(result[0].disp_status).to eq('Status not available')
      end
    end
  end

  describe 'V2StatusMapper module inclusion' do
    it 'includes V2StatusMapper module' do
      expect(described_class.ancestors).to include(UnifiedHealthData::Adapters::V2StatusMapper)
    end

    it 'has access to V2_STATUS_GROUPS constant' do
      expect(described_class::V2_STATUS_GROUPS).to be_a(Hash)
      expect(described_class::V2_STATUS_GROUPS.keys).to contain_exactly(
        'Active', 'In progress', 'Inactive', 'Transferred', 'Status not available'
      )
    end

    it 'has access to ORIGINAL_TO_V2_STATUS_MAPPING constant' do
      expect(described_class::ORIGINAL_TO_V2_STATUS_MAPPING).to be_a(Hash)
      expect(described_class::ORIGINAL_TO_V2_STATUS_MAPPING['active']).to eq('Active')
      expect(described_class::ORIGINAL_TO_V2_STATUS_MAPPING['expired']).to eq('Inactive')
    end
  end

  describe 'all V2 status mappings' do
    let(:use_v2_statuses) { true }

    # Test each original status maps to correct V2 status
    {
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
    }.each do |original_status, expected_v2_status|
      it "maps '#{original_status}' to '#{expected_v2_status}'" do
        vista_rx = OpenStruct.new(
          prescription_id: '12345',
          disp_status: original_status,
          prescription_name: 'Test Med'
        )

        result = adapter.combine_prescriptions(
          oracle_resources: [],
          vista_prescriptions: [vista_rx]
        )

        expect(result[0].disp_status).to eq(expected_v2_status)
      end
    end
  end
end
