# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/conditions_adapter'

RSpec.describe 'ConditionsAdapter' do
  let(:adapter) { UnifiedHealthData::Adapters::ConditionsAdapter.new }
  let(:conditions_sample_response) do
    JSON.parse(Rails.root.join(
      'spec', 'fixtures', 'unified_health_data', 'condition_sample_response.json'
    ).read)
  end

  let(:conditions_fallback_response) do
    {
      'vista' => {
        'entry' => [{
          'resource' => {
            'resourceType' => 'Condition',
            'id' => 'fallback-test-id',
            'code' => { 'text' => 'Condition from text field' },
            'recordedDate' => '2024-02-20T00:00:00Z',
            'asserter' => { 'display' => 'Dr. Simple Provider' },
            'encounter' => { 'display' => 'Simple Medical Center' },
            'note' => { 'text' => 'Single note text' }
          }
        }]
      }
    }
  end

  before do
    allow(UnifiedHealthData::Condition).to receive(:new).and_call_original
  end

  describe '#parse' do
    it 'returns the expected fields for vista condition with all fields' do
      vista_records = conditions_sample_response['vista']['entry']
      parsed_condition = adapter.parse(vista_records).first

      expect(parsed_condition).to have_attributes(
        id: be_present,
        name: be_present,
        date: be_present,
        provider: be_present,
        facility: be_present,
        comments: be_an(Array)
      )
    end

    it 'returns the expected fields for oracle-health condition with all fields' do
      oh_records = conditions_sample_response['oracle-health']['entry'] || []
      next if oh_records.empty?

      parsed_condition = adapter.parse(oh_records).first

      expect(parsed_condition).to have_attributes(
        id: be_present,
        name: be_present,
        date: be_present,
        provider: be_present,
        facility: be_present,
        comments: be_an(Array)
      )
    end

    it 'returns the expected fields with fallback values' do
      fallback_records = conditions_fallback_response['vista']['entry']
      parsed_condition = adapter.parse(fallback_records).first

      expect(parsed_condition).to have_attributes(
        id: 'fallback-test-id',
        name: 'Condition from text field',
        date: '2024-02-20T00:00:00Z',
        provider: 'Dr. Simple Provider',
        facility: 'Simple Medical Center',
        comments: ['Single note text']
      )
    end

    it 'handles empty records gracefully' do
      parsed_conditions = adapter.parse([])
      expect(parsed_conditions).to eq([])
    end

    it 'filters only Condition resources' do
      mixed_records = [
        { 'resource' => { 'resourceType' => 'Condition', 'id' => 'condition-1' } },
        { 'resource' => { 'resourceType' => 'DiagnosticReport', 'id' => 'report-1' } }
      ]

      parsed_conditions = adapter.parse(mixed_records)
      expect(parsed_conditions.size).to eq(1)
      expect(parsed_conditions.first.id).to eq('condition-1')
    end
  end

  describe '#parse_single_condition' do
    it 'returns nil if record is invalid' do
      expect(adapter.parse_single_condition(nil)).to be_nil
      expect(adapter.parse_single_condition({ 'resource' => nil })).to be_nil
    end
  end
end
