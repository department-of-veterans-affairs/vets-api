# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/fhir_helpers'

describe UnifiedHealthData::Adapters::FhirHelpers do
  # Create a test class that includes the module
  subject { helper_class.new }

  let(:helper_class) do
    Class.new do
      include UnifiedHealthData::Adapters::FhirHelpers
    end
  end

  describe '#parse_date_or_epoch' do
    it 'parses a valid ISO 8601 date string' do
      result = subject.parse_date_or_epoch('2025-06-24T21:05:53.000Z')
      expect(result).to be_a(Time)
      expect(result.year).to eq(2025)
      expect(result.month).to eq(6)
      expect(result.day).to eq(24)
    end

    it 'returns epoch when date_string is nil' do
      result = subject.parse_date_or_epoch(nil)
      expect(result).to eq(Time.zone.at(0))
    end

    it 'returns epoch when date_string is empty' do
      result = subject.parse_date_or_epoch('')
      # parse_date_or_epoch returns epoch for invalid dates per commit cb4123e
      expect(result).to eq(Time.zone.at(0))
    end

    it 'returns epoch for invalid date format' do
      result = subject.parse_date_or_epoch('invalid-date')
      # parse_date_or_epoch returns epoch for invalid dates per commit cb4123e
      expect(result).to eq(Time.zone.at(0))
    end

    it 'handles date with timezone offset' do
      result = subject.parse_date_or_epoch('2025-06-24T21:05:53+00:00')
      expect(result).to be_a(Time)
      expect(result.year).to eq(2025)
    end

    it 'handles date-only strings' do
      result = subject.parse_date_or_epoch('2025-06-24')
      expect(result).to be_a(Time)
      expect(result.year).to eq(2025)
      expect(result.month).to eq(6)
      expect(result.day).to eq(24)
    end
  end

  describe '#days_since' do
    before do
      Timecop.freeze(Time.zone.parse('2025-06-30T12:00:00Z'))
    end

    after do
      Timecop.return
    end

    it 'calculates days since a given date' do
      result = subject.days_since('2025-06-24T12:00:00Z')
      expect(result).to eq(6)
    end

    it 'returns 0 for today' do
      result = subject.days_since('2025-06-30T10:00:00Z')
      expect(result).to eq(0)
    end

    it 'returns nil for nil date' do
      result = subject.days_since(nil)
      expect(result).to be_nil
    end

    it 'returns nil for invalid date format' do
      result = subject.days_since('invalid-date')
      expect(result).to be_nil
    end

    it 'returns nil for future dates (negative days)' do
      result = subject.days_since('2025-07-05T12:00:00Z')
      expect(result).to be_nil
    end

    it 'handles dates without time component' do
      result = subject.days_since('2025-06-24')
      expect(result).to eq(6)
    end
  end

  describe '#find_identifier_value' do
    let(:identifiers) do
      [
        { 'type' => { 'text' => 'Tracking Number' }, 'value' => 'TRK123' },
        { 'type' => { 'text' => 'Prescription Number' }, 'value' => 'RX456' },
        { 'type' => { 'text' => 'Carrier' }, 'value' => 'USPS' }
      ]
    end

    it 'finds identifier value by type text' do
      result = subject.find_identifier_value(identifiers, 'Tracking Number')
      expect(result).to eq('TRK123')
    end

    it 'returns nil when type text not found' do
      result = subject.find_identifier_value(identifiers, 'Unknown Type')
      expect(result).to be_nil
    end

    it 'returns nil for empty identifiers array' do
      result = subject.find_identifier_value([], 'Tracking Number')
      expect(result).to be_nil
    end

    it 'handles identifiers without value' do
      identifiers_without_value = [{ 'type' => { 'text' => 'Tracking Number' } }]
      result = subject.find_identifier_value(identifiers_without_value, 'Tracking Number')
      expect(result).to be_nil
    end
  end

  describe '#extract_ndc_number' do
    it 'extracts NDC code from dispense medicationCodeableConcept' do
      dispense = {
        'medicationCodeableConcept' => {
          'coding' => [
            { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '12345-6789-01' }
          ]
        }
      }
      result = subject.extract_ndc_number(dispense)
      expect(result).to eq('12345-6789-01')
    end

    it 'returns nil when NDC coding not present' do
      dispense = {
        'medicationCodeableConcept' => {
          'coding' => [
            { 'system' => 'http://snomed.info/sct', 'code' => '123456' }
          ]
        }
      }
      result = subject.extract_ndc_number(dispense)
      expect(result).to be_nil
    end

    it 'returns nil when coding array is empty' do
      dispense = { 'medicationCodeableConcept' => { 'coding' => [] } }
      result = subject.extract_ndc_number(dispense)
      expect(result).to be_nil
    end

    it 'returns nil when medicationCodeableConcept is missing' do
      dispense = {}
      result = subject.extract_ndc_number(dispense)
      expect(result).to be_nil
    end
  end

  describe '#medication_dispenses' do
    it 'extracts MedicationDispense resources from contained array' do
      resource = {
        'contained' => [
          { 'resourceType' => 'MedicationDispense', 'id' => '1' },
          { 'resourceType' => 'Task', 'id' => '2' },
          { 'resourceType' => 'MedicationDispense', 'id' => '3' }
        ]
      }
      result = subject.medication_dispenses(resource)
      expect(result.length).to eq(2)
      expect(result.map { |d| d['id'] }).to contain_exactly('1', '3')
    end

    it 'returns empty array when no MedicationDispense resources exist' do
      resource = {
        'contained' => [
          { 'resourceType' => 'Task', 'id' => '1' },
          { 'resourceType' => 'Medication', 'id' => '2' }
        ]
      }
      result = subject.medication_dispenses(resource)
      expect(result).to eq([])
    end

    it 'returns empty array when contained is nil' do
      resource = {}
      result = subject.medication_dispenses(resource)
      expect(result).to eq([])
    end

    it 'returns empty array when contained is empty' do
      resource = { 'contained' => [] }
      result = subject.medication_dispenses(resource)
      expect(result).to eq([])
    end

    it 'handles resource with no contained key' do
      resource = { 'id' => '123' }
      result = subject.medication_dispenses(resource)
      expect(result).to eq([])
    end
  end

  describe '#find_most_recent_medication_dispense' do
    it 'returns the most recent dispense by whenHandedOver date' do
      contained_resources = [
        { 'resourceType' => 'MedicationDispense', 'whenHandedOver' => '2025-01-15T10:00:00Z', 'id' => '1' },
        { 'resourceType' => 'MedicationDispense', 'whenHandedOver' => '2025-06-20T10:00:00Z', 'id' => '2' },
        { 'resourceType' => 'MedicationDispense', 'whenHandedOver' => '2025-03-10T10:00:00Z', 'id' => '3' }
      ]
      result = subject.find_most_recent_medication_dispense(contained_resources)
      expect(result['id']).to eq('2')
    end

    it 'falls back to whenPrepared if whenHandedOver is missing' do
      contained_resources = [
        { 'resourceType' => 'MedicationDispense', 'whenPrepared' => '2025-01-15T10:00:00Z', 'id' => '1' },
        { 'resourceType' => 'MedicationDispense', 'whenPrepared' => '2025-06-20T10:00:00Z', 'id' => '2' }
      ]
      result = subject.find_most_recent_medication_dispense(contained_resources)
      expect(result['id']).to eq('2')
    end

    it 'returns nil when no MedicationDispense resources exist' do
      contained_resources = [
        { 'resourceType' => 'Task', 'id' => '1' }
      ]
      result = subject.find_most_recent_medication_dispense(contained_resources)
      expect(result).to be_nil
    end

    it 'returns nil when contained_resources is nil' do
      result = subject.find_most_recent_medication_dispense(nil)
      expect(result).to be_nil
    end

    it 'returns nil when contained_resources is empty array' do
      result = subject.find_most_recent_medication_dispense([])
      expect(result).to be_nil
    end

    it 'handles dispenses without whenHandedOver or whenPrepared (uses epoch)' do
      contained_resources = [
        { 'resourceType' => 'MedicationDispense', 'id' => '1' },
        { 'resourceType' => 'MedicationDispense', 'whenHandedOver' => '2025-01-15T10:00:00Z', 'id' => '2' }
      ]
      result = subject.find_most_recent_medication_dispense(contained_resources)
      expect(result['id']).to eq('2')
    end

    it 'handles invalid date formats gracefully' do
      contained_resources = [
        { 'resourceType' => 'MedicationDispense', 'whenHandedOver' => 'invalid-date', 'id' => '1' },
        { 'resourceType' => 'MedicationDispense', 'whenHandedOver' => '2025-01-15T10:00:00Z', 'id' => '2' }
      ]
      result = subject.find_most_recent_medication_dispense(contained_resources)
      expect(result['id']).to eq('2')
    end
  end

  describe '#build_instruction_text' do
    it 'builds instruction from timing, route, and dose' do
      instruction = {
        'timing' => { 'code' => { 'text' => 'Once daily' } },
        'route' => { 'text' => 'Oral' },
        'doseAndRate' => [
          { 'doseQuantity' => { 'value' => 10, 'unit' => 'mg' } }
        ]
      }
      result = subject.build_instruction_text(instruction)
      expect(result).to eq('Once daily Oral 10 mg')
    end

    it 'handles missing timing' do
      instruction = {
        'route' => { 'text' => 'Oral' },
        'doseAndRate' => [
          { 'doseQuantity' => { 'value' => 10, 'unit' => 'mg' } }
        ]
      }
      result = subject.build_instruction_text(instruction)
      expect(result).to eq('Oral 10 mg')
    end

    it 'handles missing route' do
      instruction = {
        'timing' => { 'code' => { 'text' => 'Once daily' } },
        'doseAndRate' => [
          { 'doseQuantity' => { 'value' => 10, 'unit' => 'mg' } }
        ]
      }
      result = subject.build_instruction_text(instruction)
      expect(result).to eq('Once daily 10 mg')
    end

    it 'handles missing doseAndRate' do
      instruction = {
        'timing' => { 'code' => { 'text' => 'Once daily' } },
        'route' => { 'text' => 'Oral' }
      }
      result = subject.build_instruction_text(instruction)
      expect(result).to eq('Once daily Oral')
    end

    it 'returns empty string for empty instruction' do
      instruction = {}
      result = subject.build_instruction_text(instruction)
      expect(result).to eq('')
    end
  end

  describe '#log_invalid_expiration_date' do
    before do
      allow(Rails.logger).to receive(:warn)
    end

    it 'logs warning with prescription id and expiration date' do
      resource = { 'id' => '12345' }
      subject.log_invalid_expiration_date(resource, 'invalid-date')
      expect(Rails.logger).to have_received(:warn)
        .with('Invalid expiration date for prescription 12345: invalid-date')
    end
  end

  describe '#extract_sig_from_dispense' do
    it 'extracts and concatenates dosage instruction texts' do
      dispense = {
        'dosageInstruction' => [
          { 'text' => 'Take 1 tablet' },
          { 'text' => 'with food' }
        ]
      }
      result = subject.extract_sig_from_dispense(dispense)
      expect(result).to eq('Take 1 tablet with food')
    end

    it 'returns nil when dosageInstruction is empty' do
      dispense = { 'dosageInstruction' => [] }
      result = subject.extract_sig_from_dispense(dispense)
      expect(result).to be_nil
    end

    it 'returns nil when dosageInstruction is missing' do
      dispense = {}
      result = subject.extract_sig_from_dispense(dispense)
      expect(result).to be_nil
    end

    it 'filters out non-hash instructions' do
      dispense = {
        'dosageInstruction' => [
          { 'text' => 'Take 1 tablet' },
          'invalid instruction',
          { 'text' => 'twice daily' }
        ]
      }
      result = subject.extract_sig_from_dispense(dispense)
      expect(result).to eq('Take 1 tablet twice daily')
    end

    it 'filters out instructions without text' do
      dispense = {
        'dosageInstruction' => [
          { 'text' => 'Take 1 tablet' },
          { 'timing' => { 'code' => 'BID' } },
          { 'text' => 'twice daily' }
        ]
      }
      result = subject.extract_sig_from_dispense(dispense)
      expect(result).to eq('Take 1 tablet twice daily')
    end
  end
end
