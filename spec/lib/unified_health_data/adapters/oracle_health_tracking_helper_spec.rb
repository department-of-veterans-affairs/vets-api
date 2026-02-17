# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/oracle_health_tracking_helper'
require 'unified_health_data/adapters/fhir_helpers'

# Test class that includes the tracking helper for testing
class TrackingHelperTestClass
  include UnifiedHealthData::Adapters::OracleHealthTrackingHelper
  include UnifiedHealthData::Adapters::FhirHelpers

  # Stub methods that the helper depends on
  def extract_prescription_name(resource)
    resource.dig('medicationCodeableConcept', 'text') || 'Default Medication Name'
  end

  def extract_prescription_number(resource)
    identifiers = resource['identifier'] || []
    prescription_id = identifiers.find { |id| id['system']&.include?('prescription') }
    prescription_id ? prescription_id['value'] : 'DEFAULT-RX-001'
  end

  def extract_ndc_number(dispense)
    coding = dispense.dig('medicationCodeableConcept', 'coding') || []
    ndc_coding = coding.find { |c| c['system'] == 'http://hl7.org/fhir/sid/ndc' }
    ndc_coding&.dig('code')
  end

  def find_most_recent_medication_dispense(resource)
    contained_resources = resource['contained'] || []
    dispenses = contained_resources.select { |c| c['resourceType'] == 'MedicationDispense' }
    dispenses.max_by { |d| d['whenHandedOver'] || '' }
  end

  def find_identifier_value(identifiers, type_text)
    identifier = identifiers.find { |id| id.dig('type', 'text') == type_text }
    identifier&.dig('value')
  end
end

describe UnifiedHealthData::Adapters::OracleHealthTrackingHelper do
  let(:helper) { TrackingHelperTestClass.new }

  # Update all test fixtures to use simple field names as URLs (matching actual Oracle Health format)
  # Change from: 'url' => 'http://example.com/tracking/Tracking Number'
  # Change to:   'url' => 'Tracking Number'

  describe '#build_tracking_information' do
    context 'with extension-based tracking data' do
      let(:resource_with_extension_tracking) do
        {
          'id' => '20848812135',
          'medicationCodeableConcept' => {
            'text' => 'albuterol 90 mcg/inh Aerosol',
            'coding' => [
              { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '00487-9801-01' }
            ]
          },
          'identifier' => [
            { 'system' => 'http://example.com/prescription', 'value' => 'RX-PLACER-001' }
          ],
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Tracking Number', 'valueString' => '9400111899223100000001' },
                    { 'url' => 'Delivery Service', 'valueString' => 'USPS' },
                    { 'url' => 'Shipped Date', 'valueString' => '2026-01-10 14:35:02.0' },
                    { 'url' => 'Prescription Name', 'valueString' => 'albuterol 90 mcg/inh Aerosol' },
                    { 'url' => 'NDC Code', 'valueString' => '00487-9801-01' },
                    { 'url' => 'Prescription Number', 'valueString' => 'RX-PLACER-001' }
                  ]
                }
              ]
            }
          ]
        }
      end

      context 'when all extension fields are present' do
        it 'returns tracking information with all extension fields' do
          result = helper.build_tracking_information(resource_with_extension_tracking)

          expect(result).to be_an(Array)
          expect(result.length).to eq(1)

          tracking = result.first
          expect(tracking[:tracking_number]).to eq('9400111899223100000001')
          expect(tracking[:carrier]).to eq('USPS')
          expect(tracking[:shipped_date]).to eq('2026-01-10 14:35:02.0')
          expect(tracking[:prescription_name]).to eq('albuterol 90 mcg/inh Aerosol')
          expect(tracking[:ndc_number]).to eq('00487-9801-01')
          expect(tracking[:prescription_number]).to eq('RX-PLACER-001')
          expect(tracking[:prescription_id]).to eq('20848812135')
          expect(tracking[:other_prescriptions]).to eq([])
        end
      end

      context 'when extension has only tracking number' do
        let(:resource_with_minimal_extension) do
          {
            'id' => '12345',
            'medicationCodeableConcept' => {
              'text' => 'Test Medication',
              'coding' => [
                { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '11111-2222-33' }
              ]
            },
            'identifier' => [
              { 'system' => 'http://example.com/prescription', 'value' => 'TEST-001' }
            ],
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'extension' => [
                  {
                    'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                    'extension' => [
                      { 'url' => 'Tracking Number', 'valueString' => '9999888877776666' }
                    ]
                  }
                ]
              }
            ]
          }
        end

        it 'falls back to resource extraction methods for missing fields' do
          result = helper.build_tracking_information(resource_with_minimal_extension)

          expect(result).to be_an(Array)
          expect(result.length).to eq(1)

          tracking = result.first
          expect(tracking[:tracking_number]).to eq('9999888877776666')
          expect(tracking[:prescription_name]).to eq('Test Medication')
          expect(tracking[:prescription_number]).to eq('TEST-001')
          expect(tracking[:ndc_number]).to eq('11111-2222-33')
        end
      end

      context 'when NDC is in resource coding but not in extension' do
        let(:resource_with_ndc_in_coding) do
          {
            'id' => '12345',
            'medicationCodeableConcept' => {
              'coding' => [
                { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '00487-9801-01' }
              ]
            },
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'extension' => [
                  {
                    'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                    'extension' => [
                      { 'url' => 'Tracking Number', 'valueString' => '12345' }
                    ]
                  }
                ]
              }
            ]
          }
        end

        it 'extracts NDC from resource coding array' do
          result = helper.build_tracking_information(resource_with_ndc_in_coding)

          expect(result.first[:ndc_number]).to eq('00487-9801-01')
        end
      end

      context 'when NDC is only in most recent dispense' do
        let(:resource_with_dispense_ndc) do
          {
            'id' => '12345',
            'medicationCodeableConcept' => {
              'coding' => [
                { 'system' => 'http://rxnorm.org', 'code' => 'RXNORM-456' }
              ]
            },
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'whenHandedOver' => '2025-11-17T21:35:02.000Z',
                'medicationCodeableConcept' => {
                  'coding' => [
                    { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '99999-8888-77' }
                  ]
                },
                'extension' => [
                  {
                    'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                    'extension' => [
                      { 'url' => 'Tracking Number', 'valueString' => '12345' }
                    ]
                  }
                ]
              }
            ]
          }
        end

        it 'falls back to dispense NDC' do
          result = helper.build_tracking_information(resource_with_dispense_ndc)

          expect(result.first[:ndc_number]).to eq('99999-8888-77')
        end
      end
    end

    context 'with extension-based and identifier-based tracking in same resource' do
      let(:resource_with_both_formats) do
        {
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Tracking Number', 'valueString' => 'EXT-123456' }
                  ]
                }
              ],
              'identifier' => [
                { 'type' => { 'text' => 'Tracking Number' }, 'value' => 'ID-789012' }
              ]
            }
          ]
        }
      end

      it 'prioritizes extension-based tracking over identifier-based' do
        result = helper.build_tracking_information(resource_with_both_formats)

        expect(result.length).to eq(1)
        expect(result.first[:tracking_number]).to eq('EXT-123456')
      end
    end

    context 'with multiple dispenses' do
      let(:resource_with_multiple_dispenses) do
        {
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Tracking Number', 'valueString' => 'TRACK-001' }
                  ]
                }
              ]
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-2',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Tracking Number', 'valueString' => 'TRACK-002' }
                  ]
                }
              ]
            }
          ]
        }
      end

      it 'returns tracking for all dispenses with tracking data' do
        result = helper.build_tracking_information(resource_with_multiple_dispenses)

        expect(result.length).to eq(2)
        expect(result.map { |t| t[:tracking_number] }).to contain_exactly('TRACK-001', 'TRACK-002')
      end
    end

    context 'with mixed dispenses (some with tracking, some without)' do
      let(:resource_with_mixed_dispenses) do
        {
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Tracking Number', 'valueString' => 'TRACK-001' }
                  ]
                }
              ]
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-2',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Delivery Service', 'valueString' => 'USPS' }
                  ]
                }
              ]
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-3'
            }
          ]
        }
      end

      it 'returns only tracking for dispenses with tracking numbers' do
        result = helper.build_tracking_information(resource_with_mixed_dispenses)

        expect(result.length).to eq(1)
        expect(result.first[:tracking_number]).to eq('TRACK-001')
      end
    end
  end
end
