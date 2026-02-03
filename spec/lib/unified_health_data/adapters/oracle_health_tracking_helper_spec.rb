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

  describe '#build_tracking_information' do
    context 'with extension-based tracking data' do
      context 'when all extension fields are present' do
        let(:resource) do
          {
            'id' => '12345',
            'medicationCodeableConcept' => {
              'text' => 'albuterol 90 mcg/inh Aerosol',
              'coding' => [
                { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '00487-9801-01' }
              ]
            },
            'identifier' => [
              { 'system' => 'http://example.com/prescription', 'value' => 'RX-001' }
            ],
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'extension' => [
                  {
                    'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                    'extension' => [
                      { 'url' => 'http://example.com/Tracking Number', 'valueString' => '9400111899223100000001' },
                      { 'url' => 'http://example.com/Delivery Service', 'valueString' => 'USPS' },
                      { 'url' => 'http://example.com/Shipped Date', 'valueString' => '2026-01-10 14:35:02.0' },
                      { 'url' => 'http://example.com/Prescription Name', 'valueString' => 'Extension Med Name' },
                      { 'url' => 'http://example.com/Prescription Number', 'valueString' => 'EXT-RX-999' },
                      { 'url' => 'http://example.com/NDC Code', 'valueString' => '99999-9999-99' }
                    ]
                  }
                ]
              }
            ]
          }
        end

        it 'returns tracking information with all extension fields' do
          result = helper.build_tracking_information(resource)

          expect(result).to be_an(Array)
          expect(result.length).to eq(1)

          tracking = result.first
          expect(tracking[:tracking_number]).to eq('9400111899223100000001')
          expect(tracking[:carrier]).to eq('USPS')
          expect(tracking[:shipped_date]).to eq('2026-01-10 14:35:02.0')
          expect(tracking[:prescription_name]).to eq('Extension Med Name')
          expect(tracking[:prescription_number]).to eq('EXT-RX-999')
          expect(tracking[:ndc_number]).to eq('99999-9999-99')
          expect(tracking[:prescription_id]).to eq('12345')
          expect(tracking[:other_prescriptions]).to eq([])
        end
      end

      context 'when extension has only tracking number' do
        let(:resource) do
          {
            'id' => '12345',
            'medicationCodeableConcept' => {
              'text' => 'Fallback Medication',
              'coding' => [
                { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '11111-2222-33' }
              ]
            },
            'identifier' => [
              { 'system' => 'http://example.com/prescription', 'value' => 'FALLBACK-RX' }
            ],
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'extension' => [
                  {
                    'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                    'extension' => [
                      { 'url' => 'http://example.com/Tracking Number', 'valueString' => 'MINIMAL-TRACK' }
                    ]
                  }
                ]
              }
            ]
          }
        end

        it 'falls back to resource extraction methods for missing fields' do
          result = helper.build_tracking_information(resource)

          tracking = result.first
          expect(tracking[:tracking_number]).to eq('MINIMAL-TRACK')
          expect(tracking[:carrier]).to be_nil
          expect(tracking[:shipped_date]).to be_nil
          # Fallback values from resource
          expect(tracking[:prescription_name]).to eq('Fallback Medication')
          expect(tracking[:prescription_number]).to eq('FALLBACK-RX')
          expect(tracking[:ndc_number]).to eq('11111-2222-33')
        end
      end

      context 'when extension has no tracking number' do
        let(:resource) do
          {
            'id' => '12345',
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'extension' => [
                  {
                    'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                    'extension' => [
                      { 'url' => 'http://example.com/Delivery Service', 'valueString' => 'USPS' }
                    ]
                  }
                ]
              }
            ]
          }
        end

        it 'does not create tracking record without tracking number' do
          result = helper.build_tracking_information(resource)
          expect(result).to eq([])
        end
      end

      context 'when shipping extension has empty nested extensions' do
        let(:resource) do
          {
            'id' => '12345',
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'extension' => [
                  {
                    'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                    'extension' => []
                  }
                ]
              }
            ]
          }
        end

        it 'does not create tracking record' do
          result = helper.build_tracking_information(resource)
          expect(result).to eq([])
        end
      end

      context 'when dispense has non-shipping extensions only' do
        let(:resource) do
          {
            'id' => '12345',
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'extension' => [
                  {
                    'url' => 'http://example.com/other-extension',
                    'extension' => [
                      { 'url' => 'Some Field', 'valueString' => 'some value' }
                    ]
                  }
                ]
              }
            ]
          }
        end

        it 'does not create tracking record' do
          result = helper.build_tracking_information(resource)
          expect(result).to eq([])
        end
      end

      context 'when NDC is in resource coding but not in extension' do
        let(:resource) do
          {
            'id' => '12345',
            'medicationCodeableConcept' => {
              'coding' => [
                { 'system' => 'http://rxnorm.org', 'code' => 'RXNORM-123' },
                { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '55555-4444-33' }
              ]
            },
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'extension' => [
                  {
                    'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                    'extension' => [
                      { 'url' => 'http://example.com/Tracking Number', 'valueString' => 'TRACK-123' }
                    ]
                  }
                ]
              }
            ]
          }
        end

        it 'extracts NDC from resource coding array' do
          result = helper.build_tracking_information(resource)
          expect(result.first[:ndc_number]).to eq('55555-4444-33')
        end
      end

      context 'when NDC is only in most recent dispense' do
        let(:resource) do
          {
            'id' => '12345',
            'medicationCodeableConcept' => {
              'coding' => [
                { 'system' => 'http://rxnorm.org', 'code' => 'RXNORM-123' }
              ]
            },
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'whenHandedOver' => '2025-11-17T21:35:02.000Z',
                'medicationCodeableConcept' => {
                  'coding' => [
                    { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => 'DISPENSE-NDC-001' }
                  ]
                },
                'extension' => [
                  {
                    'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                    'extension' => [
                      { 'url' => 'http://example.com/Tracking Number', 'valueString' => 'TRACK-456' }
                    ]
                  }
                ]
              }
            ]
          }
        end

        it 'falls back to dispense NDC' do
          result = helper.build_tracking_information(resource)
          expect(result.first[:ndc_number]).to eq('DISPENSE-NDC-001')
        end
      end
    end

    context 'with legacy identifier-based tracking data' do
      context 'when all identifier fields are present' do
        let(:resource) do
          {
            'id' => '67890',
            'medicationCodeableConcept' => { 'text' => 'Test Medication' },
            'identifier' => [
              { 'system' => 'http://example.com/prescription', 'value' => 'RX-002' }
            ],
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'identifier' => [
                  { 'type' => { 'text' => 'Tracking Number' }, 'value' => 'LEGACY-123' },
                  { 'type' => { 'text' => 'Carrier' }, 'value' => 'UPS' },
                  { 'type' => { 'text' => 'Shipped Date' }, 'value' => '2026-01-15' },
                  { 'type' => { 'text' => 'Prescription Number' }, 'value' => 'LEGACY-RX-999' }
                ],
                'medicationCodeableConcept' => {
                  'coding' => [
                    { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '11111-2222-33' }
                  ]
                }
              }
            ]
          }
        end

        it 'returns tracking information from identifiers' do
          result = helper.build_tracking_information(resource)

          expect(result).to be_an(Array)
          expect(result.length).to eq(1)

          tracking = result.first
          expect(tracking[:tracking_number]).to eq('LEGACY-123')
          expect(tracking[:carrier]).to eq('UPS')
          expect(tracking[:shipped_date]).to eq('2026-01-15')
          expect(tracking[:prescription_number]).to eq('LEGACY-RX-999')
          expect(tracking[:ndc_number]).to eq('11111-2222-33')
          expect(tracking[:prescription_id]).to eq('67890')
        end
      end

      context 'when identifier has only tracking number' do
        let(:resource) do
          {
            'id' => '67890',
            'medicationCodeableConcept' => { 'text' => 'Minimal Med' },
            'identifier' => [
              { 'system' => 'http://example.com/prescription', 'value' => 'MINIMAL-RX' }
            ],
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'identifier' => [
                  { 'type' => { 'text' => 'Tracking Number' }, 'value' => 'MINIMAL-TRACK' }
                ]
              }
            ]
          }
        end

        it 'uses resource fallback for missing identifier fields' do
          result = helper.build_tracking_information(resource)

          tracking = result.first
          expect(tracking[:tracking_number]).to eq('MINIMAL-TRACK')
          expect(tracking[:carrier]).to be_nil
          expect(tracking[:shipped_date]).to be_nil
          expect(tracking[:prescription_name]).to eq('Minimal Med')
          expect(tracking[:prescription_number]).to eq('MINIMAL-RX')
        end
      end

      context 'when identifier has no tracking number' do
        let(:resource) do
          {
            'id' => '67890',
            'contained' => [
              {
                'resourceType' => 'MedicationDispense',
                'identifier' => [
                  { 'type' => { 'text' => 'Carrier' }, 'value' => 'FedEx' }
                ]
              }
            ]
          }
        end

        it 'does not create tracking record without tracking number' do
          result = helper.build_tracking_information(resource)
          expect(result).to eq([])
        end
      end
    end

    context 'with extension-based and identifier-based tracking in same resource' do
      let(:resource) do
        {
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'identifier' => [
                { 'type' => { 'text' => 'Tracking Number' }, 'value' => 'LEGACY-TRACK' }
              ],
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'http://example.com/Tracking Number', 'valueString' => 'EXTENSION-TRACK' }
                  ]
                }
              ]
            }
          ]
        }
      end

      it 'prioritizes extension-based tracking over identifier-based' do
        result = helper.build_tracking_information(resource)

        expect(result.length).to eq(1)
        expect(result.first[:tracking_number]).to eq('EXTENSION-TRACK')
      end
    end

    context 'with no tracking data' do
      let(:resource) do
        {
          'id' => '99999',
          'contained' => [
            { 'resourceType' => 'MedicationDispense' }
          ]
        }
      end

      it 'returns empty array' do
        result = helper.build_tracking_information(resource)
        expect(result).to eq([])
      end
    end

    context 'with no dispenses' do
      let(:resource) do
        {
          'id' => '99999',
          'contained' => []
        }
      end

      it 'returns empty array' do
        result = helper.build_tracking_information(resource)
        expect(result).to eq([])
      end
    end

    context 'with multiple dispenses' do
      let(:resource) do
        {
          'id' => '55555',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'http://example.com/Tracking Number', 'valueString' => 'TRACK-001' },
                    { 'url' => 'http://example.com/Delivery Service', 'valueString' => 'USPS' }
                  ]
                }
              ]
            },
            {
              'resourceType' => 'MedicationDispense',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'http://example.com/Tracking Number', 'valueString' => 'TRACK-002' },
                    { 'url' => 'http://example.com/Delivery Service', 'valueString' => 'FedEx' }
                  ]
                }
              ]
            }
          ]
        }
      end

      it 'returns tracking for all dispenses with tracking data' do
        result = helper.build_tracking_information(resource)

        expect(result.length).to eq(2)
        tracking_numbers = result.map { |t| t[:tracking_number] }
        expect(tracking_numbers).to contain_exactly('TRACK-001', 'TRACK-002')

        carriers = result.map { |t| t[:carrier] }
        expect(carriers).to contain_exactly('USPS', 'FedEx')
      end
    end

    context 'with mixed dispenses (some with tracking, some without)' do
      let(:resource) do
        {
          'id' => '44444',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'http://example.com/Tracking Number', 'valueString' => 'TRACK-ONLY' }
                  ]
                }
              ]
            },
            {
              'resourceType' => 'MedicationDispense'
              # No tracking data
            },
            {
              'resourceType' => 'MedicationDispense',
              'identifier' => [
                { 'type' => { 'text' => 'Carrier' }, 'value' => 'UPS' }
                # No tracking number
              ]
            }
          ]
        }
      end

      it 'returns only tracking for dispenses with tracking numbers' do
        result = helper.build_tracking_information(resource)

        expect(result.length).to eq(1)
        expect(result.first[:tracking_number]).to eq('TRACK-ONLY')
      end
    end

    context 'with dispense having no extension or identifier key' do
      let(:resource) do
        {
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'status' => 'completed'
            }
          ]
        }
      end

      it 'returns empty array' do
        result = helper.build_tracking_information(resource)
        expect(result).to eq([])
      end
    end
  end
end
