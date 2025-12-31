# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/oracle_health_medication_categorizer_helper'

describe UnifiedHealthData::Adapters::OracleHealthMedicationCategorizerHelper do
  # Create a test class that includes the module
  subject { helper_class.new }

  let(:helper_class) do
    Class.new do
      include UnifiedHealthData::Adapters::OracleHealthMedicationCategorizerHelper
    end
  end

  describe '#extract_category' do
    let(:base_resource) do
      {
        'resourceType' => 'MedicationRequest',
        'id' => '12345'
      }
    end

    context 'with category field containing inpatient code' do
      let(:resource_with_inpatient_category) do
        base_resource.merge(
          'category' => [
            {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-admin-location',
                  'code' => 'inpatient'
                }
              ]
            }
          ]
        )
      end

      it 'returns array with inpatient' do
        result = subject.send(:extract_category, resource_with_inpatient_category)
        expect(result).to eq(['inpatient'])
      end
    end

    context 'with category field containing outpatient code' do
      let(:resource_with_outpatient_category) do
        base_resource.merge(
          'category' => [
            {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-admin-location',
                  'code' => 'outpatient'
                }
              ]
            }
          ]
        )
      end

      it 'returns array with outpatient' do
        result = subject.send(:extract_category, resource_with_outpatient_category)
        expect(result).to eq(['outpatient'])
      end
    end

    context 'with category field containing community code' do
      let(:resource_with_community_category) do
        base_resource.merge(
          'category' => [
            {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-admin-location',
                  'code' => 'community'
                }
              ]
            }
          ]
        )
      end

      it 'returns array with community' do
        result = subject.send(:extract_category, resource_with_community_category)
        expect(result).to eq(['community'])
      end
    end

    context 'with multiple category codes' do
      let(:resource_with_multiple_categories) do
        base_resource.merge(
          'category' => [
            {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-admin-location',
                  'code' => 'Inpatient'
                }
              ]
            },
            {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-admin-location',
                  'code' => 'COMMUNITY'
                }
              ]
            }
          ]
        )
      end

      it 'returns sorted, lowercased array with all category codes' do
        result = subject.send(:extract_category, resource_with_multiple_categories)
        expect(result).to eq(%w[community inpatient])
      end
    end

    context 'with no category field' do
      it 'returns empty array' do
        result = subject.send(:extract_category, base_resource)
        expect(result).to eq([])
      end
    end

    context 'with empty category array' do
      let(:resource_with_empty_category) do
        base_resource.merge('category' => [])
      end

      it 'returns empty array' do
        result = subject.send(:extract_category, resource_with_empty_category)
        expect(result).to eq([])
      end
    end

    context 'with category but no coding' do
      let(:resource_with_category_no_coding) do
        base_resource.merge(
          'category' => [
            {
              'text' => 'Inpatient'
            }
          ]
        )
      end

      it 'returns empty array' do
        result = subject.send(:extract_category, resource_with_category_no_coding)
        expect(result).to eq([])
      end
    end
  end

  describe '#categorize_medication' do
    let(:base_resource) do
      {
        'resourceType' => 'MedicationRequest',
        'id' => '12345'
      }
    end

    context 'VA Prescription' do
      let(:va_prescription_resource) do
        base_resource.merge(
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'discharge' }] }
          ]
        )
      end

      it 'returns :va_prescription' do
        expect(subject.categorize_medication(va_prescription_resource)).to eq(:va_prescription)
      end

      it 'is case-insensitive for category codes' do
        resource = base_resource.merge(
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'COMMUNITY' }] },
            { 'coding' => [{ 'code' => 'Discharge' }] }
          ]
        )
        expect(subject.categorize_medication(resource)).to eq(:va_prescription)
      end
    end

    context 'Documented/Non-VA Medication' do
      let(:non_va_resource) do
        base_resource.merge(
          'reportedBoolean' => true,
          'intent' => 'plan',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'patientspecified' }] }
          ]
        )
      end

      it 'returns :documented_non_va' do
        expect(subject.categorize_medication(non_va_resource)).to eq(:documented_non_va)
      end
    end

    context 'Clinic Administered Medication' do
      let(:clinic_administered_resource) do
        base_resource.merge(
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'outpatient' }] }
          ]
        )
      end

      it 'returns :clinic_administered' do
        expect(subject.categorize_medication(clinic_administered_resource)).to eq(:clinic_administered)
      end
    end

    context 'Pharmacy Charges' do
      let(:pharmacy_charges_resource) do
        base_resource.merge(
          'category' => [
            { 'coding' => [{ 'code' => 'charge-only' }] }
          ]
        )
      end

      it 'returns :pharmacy_charges' do
        expect(subject.categorize_medication(pharmacy_charges_resource)).to eq(:pharmacy_charges)
      end

      it 'ignores reportedBoolean and intent for charge-only' do
        resource = base_resource.merge(
          'reportedBoolean' => true,
          'intent' => 'plan',
          'category' => [
            { 'coding' => [{ 'code' => 'charge-only' }] }
          ]
        )
        expect(subject.categorize_medication(resource)).to eq(:pharmacy_charges)
      end
    end

    context 'Inpatient Medication' do
      let(:inpatient_resource) do
        base_resource.merge(
          'category' => [
            { 'coding' => [{ 'code' => 'inpatient' }] }
          ]
        )
      end

      it 'returns :inpatient' do
        expect(subject.categorize_medication(inpatient_resource)).to eq(:inpatient)
      end
    end

    context 'Uncategorized' do
      it 'returns :uncategorized for missing category' do
        expect(subject.categorize_medication(base_resource)).to eq(:uncategorized)
      end

      it 'returns :uncategorized for partial match (wrong intent)' do
        resource = base_resource.merge(
          'reportedBoolean' => false,
          'intent' => 'plan', # Wrong - should be 'order' for VA prescription
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'discharge' }] }
          ]
        )
        expect(subject.categorize_medication(resource)).to eq(:uncategorized)
      end

      it 'returns :uncategorized for partial match (wrong reportedBoolean)' do
        resource = base_resource.merge(
          'reportedBoolean' => true, # Wrong - should be false for VA prescription
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'discharge' }] }
          ]
        )
        expect(subject.categorize_medication(resource)).to eq(:uncategorized)
      end

      it 'returns :uncategorized for extra category codes' do
        resource = base_resource.merge(
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'discharge' }] },
            { 'coding' => [{ 'code' => 'extra' }] } # Extra code makes it not match exactly
          ]
        )
        expect(subject.categorize_medication(resource)).to eq(:uncategorized)
      end

      it 'returns :uncategorized for missing category codes' do
        resource = base_resource.merge(
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] }
            # Missing 'discharge' code
          ]
        )
        expect(subject.categorize_medication(resource)).to eq(:uncategorized)
      end
    end
  end
end
