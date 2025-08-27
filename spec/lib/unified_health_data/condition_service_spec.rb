# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/condition_service'

RSpec.describe UnifiedHealthData::ConditionService do
  let(:user) { build(:user, :mhv) }
  let(:service) { described_class.new(user) }

  describe '#get_conditions' do
    before do
      allow(service).to receive_messages(
        fetch_access_token: 'Bearer test-token',
        perform: double(body: response_body)
      )
    end

    context 'with FHIR Condition resources' do
      let(:response_body) do
        Rails.root.join('spec', 'fixtures', 'unified_health_data', 'condition_sample_response.json').read
      end

      it 'parses conditions correctly without date filtering' do
        conditions = service.get_conditions

        # Should return all Vista + Oracle Health conditions
        expect(conditions.size).to eq(17)

        # Test first Vista condition
        first_condition = conditions[0]
        expect(first_condition.id).to eq('2b4de3e7-0ced-43c6-9a8a-336b9171f4df')
        expect(first_condition.attributes.name).to eq('Major depressive disorder, recurrent, moderate')
        expect(first_condition.attributes.provider).to eq('BORLAND,VICTORIA A')
        expect(first_condition.attributes.facility).to eq('CHYSHR TEST LAB')
        expect(first_condition.attributes.comments).to be_nil

        # Test that Oracle Health condition is included
        oracle_condition = conditions.find { |c| c.id == 'p1533314061' }
        expect(oracle_condition).not_to be_nil
        expect(oracle_condition.attributes.name).to eq('Disease caused by 2019 novel coronavirus')
        expect(oracle_condition.attributes.comments).to eq(
          'This problem was added by Discern Expert for positive COVID-19 lab test.'
        )
      end
    end

    context 'with empty response' do
      let(:response_body) { '{"vista": {"entry": []}}' }

      it 'returns empty array' do
        conditions = service.get_conditions
        expect(conditions).to be_empty
      end
    end

    context 'with malformed JSON' do
      let(:response_body) { 'invalid json' }

      it 'raises BackendServiceException' do
        expect { service.get_conditions }.to raise_error(Common::Exceptions::BackendServiceException)
      end
    end

    context 'only processes Condition resources' do
      let(:response_body) do
        {
          'vista' => {
            'entry' => [
              {
                'resource' => {
                  'resourceType' => 'Condition',
                  'id' => 'condition-1',
                  'code' => { 'coding' => [{ 'display' => 'Test Condition' }] }
                }
              },
              {
                'resource' => {
                  'resourceType' => 'DocumentReference',
                  'id' => 'doc-1',
                  'type' => { 'text' => 'Should be ignored' }
                }
              }
            ]
          }
        }.to_json
      end

      it 'only returns Condition resources, ignores DocumentReference' do
        conditions = service.get_conditions

        expect(conditions.size).to eq(1)
        expect(conditions.first.id).to eq('condition-1')
        expect(conditions.first.attributes.name).to eq('Test Condition')
      end
    end
  end

  describe 'FHIR mapping methods' do
    let(:service_instance) { described_class.new(user) }

    describe '#extract_condition_name' do
      it 'prefers code.text over coding display' do
        resource = {
          'code' => {
            'text' => 'Preferred Name',
            'coding' => [{ 'display' => 'Coding Display' }]
          }
        }
        expect(service_instance.send(:extract_condition_name, resource)).to eq('Preferred Name')
      end

      it 'uses coding display when text missing' do
        resource = {
          'code' => {
            'coding' => [
              { 'display' => 'First Display' },
              { 'display' => 'Second Display' }
            ]
          }
        }
        expect(service_instance.send(:extract_condition_name, resource)).to eq('First Display, Second Display')
      end

      it 'uses coding code when display missing' do
        resource = {
          'code' => {
            'coding' => [{ 'code' => 'I10' }]
          }
        }
        expect(service_instance.send(:extract_condition_name, resource)).to eq('I10')
      end
    end

    describe '#extract_condition_date' do
      it 'prefers recordedDate' do
        resource = {
          'recordedDate' => '2025-01-15T10:30:00Z',
          'onsetDateTime' => '2024-01-01T00:00:00Z'
        }
        result = service_instance.send(:extract_condition_date, resource)
        expect(result).to start_with('2025-01-15')
      end

      it 'falls back to onsetDateTime' do
        resource = {
          'onsetDateTime' => '2024-01-01T00:00:00Z'
        }
        result = service_instance.send(:extract_condition_date, resource)
        expect(result).to start_with('2024-01-01')
      end

      it 'uses onsetPeriod.start' do
        resource = {
          'onsetPeriod' => { 'start' => '2023-06-15T12:00:00Z' }
        }
        result = service_instance.send(:extract_condition_date, resource)
        expect(result).to start_with('2023-06-15')
      end

      it 'returns nil when no date fields present' do
        resource = {
          'code' => { 'text' => 'Condition without date' }
        }
        result = service_instance.send(:extract_condition_date, resource)
        expect(result).to be_nil
      end
    end

    describe '#extract_condition_provider' do
      it 'prefers asserter display' do
        resource = {
          'asserter' => { 'display' => 'Dr. Asserter' },
          'contained' => [
            { 'resourceType' => 'Practitioner', 'name' => [{ 'text' => 'Dr. Contained' }] }
          ]
        }
        expect(service_instance.send(:extract_condition_provider, resource)).to eq('Dr. Asserter')
      end

      it 'falls back to contained practitioner' do
        resource = {
          'contained' => [
            { 'resourceType' => 'Practitioner', 'name' => [{ 'text' => 'Dr. Contained' }] }
          ]
        }
        expect(service_instance.send(:extract_condition_provider, resource)).to eq('Dr. Contained')
      end

      it 'returns nil when no provider information available' do
        resource = {
          'code' => { 'text' => 'Condition without provider' }
        }
        result = service_instance.send(:extract_condition_provider, resource)
        expect(result).to be_nil
      end
    end

    describe '#extract_condition_facility' do
      it 'extracts facility from contained Location' do
        resource = {
          'contained' => [
            { 'resourceType' => 'Location', 'name' => 'Test Facility' }
          ]
        }
        result = service_instance.send(:extract_condition_facility, resource)
        expect(result).to eq('Test Facility')
      end

      it 'returns nil when no facility information available' do
        resource = {
          'code' => { 'text' => 'Condition without facility' }
        }
        result = service_instance.send(:extract_condition_facility, resource)
        expect(result).to be_nil
      end
    end
  end
end
