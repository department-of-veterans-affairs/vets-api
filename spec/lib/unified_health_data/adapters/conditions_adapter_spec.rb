# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/conditions_adapter'

describe UnifiedHealthData::Adapters::ConditionsAdapter, type: :service do
  subject(:adapter) { described_class.new }

  let(:conditions_response) do
    file_path = Rails.root.join('spec', 'fixtures', 'unified_health_data', 'condition_sample_response.json')
    JSON.parse(File.read(file_path))
  end

  describe '#parse' do
    context 'with valid condition responses' do
      it 'returns array of conditions' do
        combined_records = conditions_response['vista']['entry'] + (conditions_response['oracle-health']['entry'] || [])
        conditions = adapter.parse(combined_records)

        expect(conditions).to be_an(Array)
        expect(conditions.size).to be_positive
        expect(conditions.first).to be_a(UnifiedHealthData::Condition)
      end

      it 'filters only Condition resources' do
        mixed_records = [
          { 'resource' => { 'resourceType' => 'Condition', 'id' => 'condition-1' } },
          { 'resource' => { 'resourceType' => 'DiagnosticReport', 'id' => 'report-1' } },
          { 'resource' => { 'resourceType' => 'Condition', 'id' => 'condition-2' } }
        ]

        conditions = adapter.parse(mixed_records)
        expect(conditions.size).to eq(2)
      end

      it 'handles empty records' do
        conditions = adapter.parse([])
        expect(conditions).to eq([])
      end

      it 'handles nil records' do
        conditions = adapter.parse(nil)
        expect(conditions).to eq([])
      end
    end
  end

  describe '#parse_single_condition' do
    let(:condition_record) do
      {
        'resource' => {
          'resourceType' => 'Condition',
          'id' => 'test-id-123',
          'code' => { 'coding' => [{ 'display' => 'Test Condition' }] },
          'onsetDateTime' => '2024-01-15T00:00:00Z',
          'contained' => [
            {
              'resourceType' => 'Practitioner',
              'name' => [{ 'text' => 'Dr. Test Provider' }]
            },
            {
              'resourceType' => 'Location',
              'name' => 'Test Medical Center'
            }
          ]
        }
      }
    end

    it 'parses a single condition correctly' do
      condition = adapter.parse_single_condition(condition_record)

      expect(condition).to be_a(UnifiedHealthData::Condition)
      expect(condition.id).to eq('test-id-123')
      expect(condition.date).to eq('2024-01-15T00:00:00Z')
      expect(condition.name).to eq('Test Condition')
      expect(condition.provider).to eq('Dr. Test Provider')
      expect(condition.facility).to eq('Test Medical Center')
    end

    it 'uses recordedDate when onsetDateTime is not available' do
      record_with_recorded_date = condition_record.deep_dup
      record_with_recorded_date['resource'].delete('onsetDateTime')
      record_with_recorded_date['resource']['recordedDate'] = '2024-02-20T00:00:00Z'

      condition = adapter.parse_single_condition(record_with_recorded_date)
      expect(condition.date).to eq('2024-02-20T00:00:00Z')
    end

    it 'uses code text when coding display is not available' do
      record_with_text = condition_record.deep_dup
      record_with_text['resource']['code'] = { 'text' => 'Condition from text field' }

      condition = adapter.parse_single_condition(record_with_text)
      expect(condition.name).to eq('Condition from text field')
    end

    it 'handles nil record' do
      condition = adapter.parse_single_condition(nil)
      expect(condition).to be_nil
    end

    it 'handles record with nil resource' do
      condition = adapter.parse_single_condition({ 'resource' => nil })
      expect(condition).to be_nil
    end
  end

  describe '#extract_condition_comments' do
    it 'extracts single note text' do
      resource = { 'note' => [{ 'text' => 'Single comment' }] }
      comments = adapter.send(:extract_condition_comments, resource)
      expect(comments).to eq(['Single comment'])
    end

    it 'extracts multiple note texts as array' do
      resource = {
        'note' => [
          { 'text' => 'First comment' },
          { 'text' => 'Second comment' },
          { 'text' => 'Third comment' }
        ]
      }
      comments = adapter.send(:extract_condition_comments, resource)
      expect(comments).to eq(['First comment', 'Second comment', 'Third comment'])
    end

    it 'handles single note object (not array)' do
      resource = { 'note' => { 'text' => 'Single note object' } }
      comments = adapter.send(:extract_condition_comments, resource)
      expect(comments).to eq(['Single note object'])
    end

    it 'handles missing note field' do
      resource = {}
      comments = adapter.send(:extract_condition_comments, resource)
      expect(comments).to eq([])
    end

    it 'handles nil note field' do
      resource = { 'note' => nil }
      comments = adapter.send(:extract_condition_comments, resource)
      expect(comments).to eq([])
    end

    it 'filters out notes with missing text' do
      resource = {
        'note' => [
          { 'text' => 'Valid comment' },
          { 'author' => 'Dr. Smith' }, # missing text field
          { 'text' => 'Another valid comment' }
        ]
      }
      comments = adapter.send(:extract_condition_comments, resource)
      expect(comments).to eq(['Valid comment', 'Another valid comment'])
    end

    it 'handles empty note array' do
      resource = { 'note' => [] }
      comments = adapter.send(:extract_condition_comments, resource)
      expect(comments).to eq([])
    end
  end

  describe '#extract_condition_provider' do
    it 'extracts provider from contained practitioner' do
      resource = {
        'contained' => [
          { 'resourceType' => 'Practitioner', 'name' => [{ 'text' => 'Dr. Jane Smith' }] }
        ]
      }
      provider = adapter.send(:extract_condition_provider, resource)
      expect(provider).to eq('Dr. Jane Smith')
    end

    it 'falls back to asserter display when contained is missing' do
      resource = { 'asserter' => { 'display' => 'Dr. Jane Smith' } }
      provider = adapter.send(:extract_condition_provider, resource)
      expect(provider).to eq('Dr. Jane Smith')
    end

    it 'handles missing contained practitioner' do
      resource = { 'contained' => [{ 'resourceType' => 'Location', 'name' => 'Test Location' }] }
      provider = adapter.send(:extract_condition_provider, resource)
      expect(provider).to eq('')
    end

    it 'handles empty contained array' do
      resource = { 'contained' => [] }
      provider = adapter.send(:extract_condition_provider, resource)
      expect(provider).to eq('')
    end

    it 'handles missing contained field' do
      resource = {}
      provider = adapter.send(:extract_condition_provider, resource)
      expect(provider).to eq('')
    end
  end

  describe '#extract_condition_facility' do
    it 'extracts facility from contained location' do
      resource = {
        'contained' => [
          { 'resourceType' => 'Location', 'name' => 'VA Medical Center' }
        ]
      }
      facility = adapter.send(:extract_condition_facility, resource)
      expect(facility).to eq('VA Medical Center')
    end

    it 'falls back to encounter display when contained is missing' do
      resource = { 'encounter' => { 'display' => 'VA Medical Center - Primary Care' } }
      facility = adapter.send(:extract_condition_facility, resource)
      expect(facility).to eq('VA Medical Center - Primary Care')
    end

    it 'handles missing contained location' do
      resource = { 'contained' => [{ 'resourceType' => 'Practitioner', 'name' => [{ 'text' => 'Dr. Smith' }] }] }
      facility = adapter.send(:extract_condition_facility, resource)
      expect(facility).to eq('')
    end

    it 'handles empty contained array' do
      resource = { 'contained' => [] }
      facility = adapter.send(:extract_condition_facility, resource)
      expect(facility).to eq('')
    end

    it 'handles missing contained field' do
      resource = {}
      facility = adapter.send(:extract_condition_facility, resource)
      expect(facility).to eq('')
    end
  end
end
