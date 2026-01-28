# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/allergy_adapter'
require 'unified_health_data/models/allergy'

RSpec.describe 'AllergyAdapter' do
  let(:adapter) { UnifiedHealthData::Adapters::AllergyAdapter.new }
  let(:allergy_sample_response) do
    JSON.parse(Rails.root.join(
      'spec', 'fixtures', 'unified_health_data', 'allergies_example.json'
    ).read)
  end

  before do
    allow(UnifiedHealthData::Allergy).to receive(:new).and_call_original
  end

  describe '#parse' do
    # Helper method to simulate what the service's remap_vista_identifier does
    def add_vista_ids(vista_records)
      vista_records.each do |record|
        resource = record['resource']
        next unless resource && resource['identifier']

        identifier = resource['identifier'].find { |id| id['system']&.starts_with?('https://va.gov/systems/') }
        resource['id'] = identifier['value'] if identifier
      end
    end

    context 'when filter_by_status is true (default)' do
      it 'filters out VistA allergies with entered-in-error verificationStatus' do
        vista_records = allergy_sample_response['vista']['entry']
        # Add IDs like the service's remap_vista_identifier method does
        add_vista_ids(vista_records)

        # First verify that the entered-in-error record exists in fixture data
        # This ensures test will fail if fixture changes rather than silently passing
        entered_in_error_record = vista_records.find { |r| r['resource']['id'] == '2676' }
        expect(entered_in_error_record).to be_present, 'Fixture must contain VistA allergy with id 2676'
        expect(entered_in_error_record.dig('resource', 'verificationStatus', 'coding', 0,
                                           'code')).to eq('entered-in-error')

        # VistA fixture has 6 entries total, but only 5 are AllergyIntolerance resources
        # 1 of those has entered-in-error status
        expect(vista_records.length).to eq(6)

        parsed_allergies = adapter.parse(vista_records)

        # Should filter out exactly 1 record (ASPIRIN with id 2676), leaving 4
        expect(parsed_allergies.length).to eq(4)
        allergy_ids = parsed_allergies.map(&:id)
        expect(allergy_ids).not_to include('2676')
      end

      it 'filters out Oracle Health allergies with entered-in-error verificationStatus' do
        oh_records = allergy_sample_response['oracle-health']['entry']

        # First verify that the entered-in-error record exists in fixture data
        entered_in_error_record = oh_records.find { |r| r['resource']['id'] == '132316427' }
        expect(entered_in_error_record).to be_present, 'Fixture must contain OH allergy with id 132316427'
        expect(entered_in_error_record.dig('resource', 'verificationStatus', 'coding', 0,
                                           'code')).to eq('entered-in-error')

        # OH fixture has 10 entries total, but only 8 are AllergyIntolerance resources
        # 1 of those has entered-in-error status
        expect(oh_records.length).to eq(10)

        parsed_allergies = adapter.parse(oh_records)

        # Should filter out exactly 1 record (Cashew nut with id 132316427), leaving 7
        expect(parsed_allergies.length).to eq(7)
        allergy_ids = parsed_allergies.map(&:id)
        expect(allergy_ids).not_to include('132316427')
      end

      it 'includes allergies with active verificationStatus' do
        vista_records = allergy_sample_response['vista']['entry']
        add_vista_ids(vista_records)
        parsed_allergies = adapter.parse(vista_records)

        # Should include active allergies like TRAZODONE
        allergy_names = parsed_allergies.map(&:name)
        expect(allergy_names).to include('TRAZODONE')
      end

      it 'includes allergies with confirmed verificationStatus' do
        oh_records = allergy_sample_response['oracle-health']['entry']
        parsed_allergies = adapter.parse(oh_records)

        # Should include confirmed allergies like Penicillin
        allergy_names = parsed_allergies.map(&:name)
        expect(allergy_names).to include('Penicillin')
      end

      it 'includes allergies with no verificationStatus field (nil case)' do
        # Create a record without verificationStatus to explicitly test nil handling
        record_without_status = {
          'resource' => {
            'resourceType' => 'AllergyIntolerance',
            'id' => 'test-no-status',
            'code' => { 'text' => 'Test Allergy No Status' },
            'category' => [{ 'coding' => [{ 'code' => 'medication' }] }],
            'clinicalStatus' => { 'coding' => [{ 'code' => 'active' }] }
            # NOTE: verificationStatus is intentionally omitted
          }
        }

        parsed_allergies = adapter.parse([record_without_status])

        expect(parsed_allergies.length).to eq(1)
        expect(parsed_allergies.first.name).to eq('Test Allergy No Status')
      end
    end

    context 'when filter_by_status is false' do
      it 'includes VistA allergies with entered-in-error verificationStatus' do
        vista_records = allergy_sample_response['vista']['entry']
        # Add IDs like the service's remap_vista_identifier method does
        add_vista_ids(vista_records)

        parsed_allergies = adapter.parse(vista_records, filter_by_status: false)

        allergy_ids = parsed_allergies.map(&:id)
        expect(allergy_ids).to include('2676')
        # Also verify ASPIRIN is in the results by name
        allergy_names = parsed_allergies.map(&:name)
        expect(allergy_names).to include('ASPIRIN')
      end

      it 'includes Oracle Health allergies with entered-in-error verificationStatus' do
        oh_records = allergy_sample_response['oracle-health']['entry']
        parsed_allergies = adapter.parse(oh_records, filter_by_status: false)

        allergy_ids = parsed_allergies.map(&:id)
        expect(allergy_ids).to include('132316427')
        # Also verify Cashew nut is in the results by name
        allergy_names = parsed_allergies.map(&:name)
        expect(allergy_names).to include('Cashew nut (substance)')
      end
    end
  end

  describe '#parse_single_allergy' do
    # Helper to find the VistA entered-in-error record (ASPIRIN with id 2676)
    def vista_entered_in_error_record
      allergy_sample_response['vista']['entry'].find do |record|
        identifiers = record.dig('resource', 'identifier') || []
        identifiers.any? { |id| id['value'] == '2676' }
      end
    end

    # Helper to find the Oracle Health entered-in-error record (Cashew nut with id 132316427)
    def oh_entered_in_error_record
      allergy_sample_response['oracle-health']['entry'].find do |record|
        record.dig('resource', 'id') == '132316427'
      end
    end

    context 'when filter_by_status is true (default)' do
      it 'returns nil for VistA allergy with entered-in-error verificationStatus' do
        record = vista_entered_in_error_record
        parsed_allergy = adapter.parse_single_allergy(record)

        expect(parsed_allergy).to be_nil
      end

      it 'returns nil for Oracle Health allergy with entered-in-error verificationStatus' do
        record = oh_entered_in_error_record
        parsed_allergy = adapter.parse_single_allergy(record)

        expect(parsed_allergy).to be_nil
      end

      it 'returns the allergy for valid VistA record' do
        vista_single_record = allergy_sample_response['vista']['entry'][0]
        vista_identifier = vista_single_record['resource']['identifier'].find { |id| id['system'].starts_with?('https://va.gov/systems/') }
        vista_single_record['resource']['id'] = vista_identifier['value']

        parsed_allergy = adapter.parse_single_allergy(vista_single_record)

        expect(parsed_allergy).not_to be_nil
        expect(parsed_allergy.name).to eq('TRAZODONE')
      end

      it 'returns the allergy for valid Oracle Health record' do
        parsed_allergy = adapter.parse_single_allergy(allergy_sample_response['oracle-health']['entry'][0])

        expect(parsed_allergy).not_to be_nil
        expect(parsed_allergy.name).to eq('Penicillin')
      end
    end

    context 'when filter_by_status is false' do
      it 'returns VistA allergy with entered-in-error verificationStatus' do
        record = vista_entered_in_error_record
        # Add ID like the service does
        identifier = record['resource']['identifier'].find { |id| id['system']&.starts_with?('https://va.gov/systems/') }
        record['resource']['id'] = identifier['value'] if identifier

        parsed_allergy = adapter.parse_single_allergy(record, filter_by_status: false)

        expect(parsed_allergy).not_to be_nil
        expect(parsed_allergy.name).to eq('ASPIRIN')
        expect(parsed_allergy.id).to eq('2676')
      end

      it 'returns Oracle Health allergy with entered-in-error verificationStatus' do
        record = oh_entered_in_error_record
        parsed_allergy = adapter.parse_single_allergy(record, filter_by_status: false)

        expect(parsed_allergy).not_to be_nil
        expect(parsed_allergy.name).to eq('Cashew nut (substance)')
        expect(parsed_allergy.id).to eq('132316427')
      end
    end

    it 'returns the expected fields for happy path for vista allergy with all fields' do
      vista_single_record = allergy_sample_response['vista']['entry'][0]
      # This normally happens in the service, but we need the id for the test so we're mocking it here
      vista_identifier = vista_single_record['resource']['identifier'].find { |id| id['system'].starts_with?('https://va.gov/systems/') }
      vista_single_record['resource']['id'] = vista_identifier['value']
      # This also checks fallbacks and nil guards since VistA data is missing many fields
      parsed_allergy = adapter.parse_single_allergy(vista_single_record)

      expect(parsed_allergy).to have_attributes(
        {
          'id' => '2678',
          'name' => 'TRAZODONE',
          'date' => nil,
          'categories' => ['medication'],
          'reactions' => [],
          'location' => nil, # Neither OH nor VistA samples have location names
          'observedHistoric' => 'h',
          'notes' => [],
          'provider' => nil
        }
      )
    end

    it 'returns the expected fields for happy path for OH allergy with all fields' do
      parsed_allergy = adapter.parse_single_allergy(allergy_sample_response['oracle-health']['entry'][0])

      expect(parsed_allergy).to have_attributes(
        {
          'id' => '132892323',
          'name' => 'Penicillin',
          'date' => '2002',
          'categories' => ['medication'],
          'reactions' => ['Urticaria (Hives)', 'Sneezing'],
          'location' => nil, # Neither OH nor VistA samples have location names
          'observedHistoric' => nil, # OH data does not have this field
          'notes' => ['Patient reports adverse reaction to previously prescribed pencicillins'],
          'provider' => ' Victoria A Borland'
        }
      )
    end
  end
end
