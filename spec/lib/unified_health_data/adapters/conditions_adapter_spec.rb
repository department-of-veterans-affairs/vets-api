# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/conditions_adapter'

RSpec.describe UnifiedHealthData::Adapters::ConditionsAdapter, type: :service do
  let(:adapter) { UnifiedHealthData::Adapters::ConditionsAdapter.new }
  let(:conditions_sample_response) do
    JSON.parse(Rails.root.join(
      'spec', 'fixtures', 'unified_health_data', 'conditions_sample_response.json'
    ).read)
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
        date: be_a(String).or(be_nil),
        provider: be_present,
        facility: be_present,
        comments: be_an(Array)
      )
    end

    it 'returns the expected fields for oracle-health condition with all fields' do
      oh_records = conditions_sample_response['oracle-health']['entry'] || []
      skip 'No oracle-health records in fixture' if oh_records.empty?

      parsed_condition = adapter.parse(oh_records).first

      expect(parsed_condition).to have_attributes(
        id: be_present,
        name: be_present,
        date: be_present,
        provider: be_present,
        facility: be_a(String),
        comments: be_an(Array)
      )
    end

    it 'returns the expected fields with VistA sample data' do
      vista_records = conditions_sample_response['vista']['entry']
      parsed_condition = adapter.parse(vista_records).first

      expect(parsed_condition).to have_attributes(
        id: '2b4de3e7-0ced-43c6-9a8a-336b9171f4df',
        name: 'Major depressive disorder, recurrent, moderate',
        date: be_nil,
        provider: 'BORLAND,VICTORIA A',
        facility: 'CHYSHR TEST LAB',
        comments: be_an(Array)
      )
    end

    it 'returns the expected fields with Oracle Health sample data' do
      oh_records = conditions_sample_response['oracle-health']['entry']
      parsed_condition = adapter.parse(oh_records).first

      expect(parsed_condition).to have_attributes(
        id: 'p1533314061',
        name: 'Disease caused by 2019-nCoV',
        date: '2025-01-20',
        provider: 'SYSTEM, SYSTEM Cerner, Cerner Managed Acct',
        facility: 'WAMC Bariatric Surgery',
        comments: ['This problem was added by Discern Expert for positive COVID-19 lab test.']
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
end
