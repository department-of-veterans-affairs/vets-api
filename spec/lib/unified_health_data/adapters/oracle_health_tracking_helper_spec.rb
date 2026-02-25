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

      it 'logs warnings for dispenses with partial tracking info' do
        expect(Rails.logger).to receive(:warn).with(
          'OracleHealthTrackingHelper: Partial tracking info for resource 12345. ' \
          'Tracking number: present, carrier: missing'
        )
        expect(Rails.logger).to receive(:warn).with(
          'OracleHealthTrackingHelper: Partial tracking info for resource 12345. ' \
          'Tracking number: missing, carrier: present'
        )
        helper.build_tracking_information(resource_with_mixed_dispenses)
      end
    end

    context 'with multiple shipping-info extensions on a single dispense (multi-package shipment)' do
      let(:resource_with_multi_package_dispense) do
        {
          'id' => '20848812135',
          'medicationCodeableConcept' => {
            'text' => 'METFORMIN 500MG',
            'coding' => [
              { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '00591-0754-01' }
            ]
          },
          'identifier' => [
            { 'system' => 'http://example.com/prescription', 'value' => '36209961' }
          ],
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Tracking Number', 'valueString' => '515184429024' },
                    { 'url' => 'Delivery Service', 'valueString' => 'FEDEX HOME DELIVERY' },
                    { 'url' => 'Shipped Date', 'valueString' => '2026-02-06 14:00:00.0' },
                    { 'url' => 'Prescription Name', 'valueString' => 'METFORMIN 500MG' },
                    { 'url' => 'NDC Code', 'valueString' => '00591-0754-01' },
                    { 'url' => 'Prescription Number', 'valueString' => '36209961' }
                  ]
                },
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Tracking Number', 'valueString' => '515184429002' },
                    { 'url' => 'Delivery Service', 'valueString' => 'FEDEX HOME DELIVERY' },
                    { 'url' => 'Shipped Date', 'valueString' => '2026-02-06 14:00:00.0' },
                    { 'url' => 'Prescription Name', 'valueString' => 'METFORMIN 500MG' },
                    { 'url' => 'NDC Code', 'valueString' => '00591-0754-01' },
                    { 'url' => 'Prescription Number', 'valueString' => '36209961' }
                  ]
                }
              ]
            }
          ]
        }
      end

      it 'returns one tracking hash per shipping-info extension' do
        result = helper.build_tracking_information(resource_with_multi_package_dispense)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.map { |t| t[:tracking_number] }).to contain_exactly('515184429024', '515184429002')
      end

      it 'repeats shared fields on each tracking hash' do
        result = helper.build_tracking_information(resource_with_multi_package_dispense)

        result.each do |tracking|
          expect(tracking[:prescription_number]).to eq('36209961')
          expect(tracking[:shipped_date]).to eq('2026-02-06 14:00:00.0')
          expect(tracking[:prescription_name]).to eq('METFORMIN 500MG')
          expect(tracking[:ndc_number]).to eq('00591-0754-01')
          expect(tracking[:prescription_id]).to eq('20848812135')
          expect(tracking[:carrier]).to eq('FEDEX HOME DELIVERY')
        end
      end
    end

    context 'with three shipping-info extensions and mixed carriers on one dispense' do
      let(:resource_with_three_packages) do
        {
          'id' => '99999',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Tracking Number', 'valueString' => 'PKG-001' },
                    { 'url' => 'Delivery Service', 'valueString' => 'USPS' }
                  ]
                },
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Tracking Number', 'valueString' => 'PKG-002' },
                    { 'url' => 'Delivery Service', 'valueString' => 'FEDEX' }
                  ]
                },
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Tracking Number', 'valueString' => 'PKG-003' },
                    { 'url' => 'Delivery Service', 'valueString' => 'UPS' }
                  ]
                }
              ]
            }
          ]
        }
      end

      it 'returns all three tracking entries with correct carriers' do
        result = helper.build_tracking_information(resource_with_three_packages)

        expect(result.length).to eq(3)
        expect(result.map { |t| [t[:tracking_number], t[:carrier]] }).to contain_exactly(
          %w[PKG-001 USPS],
          %w[PKG-002 FEDEX],
          %w[PKG-003 UPS]
        )
      end
    end

    context 'with multi-package dispense where one extension has no tracking number' do
      let(:resource_with_partial_multi_package) do
        {
          'id' => '88888',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Tracking Number', 'valueString' => 'VALID-TRACK' },
                    { 'url' => 'Delivery Service', 'valueString' => 'USPS' }
                  ]
                },
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Delivery Service', 'valueString' => 'FEDEX' }
                  ]
                }
              ]
            }
          ]
        }
      end

      it 'returns only extensions that have a tracking number' do
        result = helper.build_tracking_information(resource_with_partial_multi_package)

        expect(result.length).to eq(1)
        expect(result.first[:tracking_number]).to eq('VALID-TRACK')
      end

      it 'logs a warning for the extension with carrier but no tracking number' do
        expect(Rails.logger).to receive(:warn).with(
          'OracleHealthTrackingHelper: Partial tracking info for resource 88888. ' \
          'Tracking number: missing, carrier: present'
        )
        helper.build_tracking_information(resource_with_partial_multi_package)
      end
    end

    context 'with tracking number but no carrier (partial tracking info)' do
      let(:resource_with_tracking_no_carrier) do
        {
          'id' => '77777',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Tracking Number', 'valueString' => 'TRACK-NO-CARRIER' },
                    { 'url' => 'Shipped Date', 'valueString' => '2026-02-10 10:00:00.0' }
                  ]
                }
              ]
            }
          ]
        }
      end

      it 'still returns the tracking hash with a nil carrier' do
        result = helper.build_tracking_information(resource_with_tracking_no_carrier)

        expect(result.length).to eq(1)
        expect(result.first[:tracking_number]).to eq('TRACK-NO-CARRIER')
        expect(result.first[:carrier]).to be_nil
      end

      it 'logs a warning about partial tracking info' do
        expect(Rails.logger).to receive(:warn).with(
          'OracleHealthTrackingHelper: Partial tracking info for resource 77777. ' \
          'Tracking number: present, carrier: missing'
        )
        helper.build_tracking_information(resource_with_tracking_no_carrier)
      end
    end

    context 'with carrier but no tracking number (partial tracking info)' do
      let(:resource_with_carrier_no_tracking) do
        {
          'id' => '66666',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Delivery Service', 'valueString' => 'UPS' },
                    { 'url' => 'Shipped Date', 'valueString' => '2026-02-10 10:00:00.0' }
                  ]
                }
              ]
            }
          ]
        }
      end

      it 'returns no tracking results' do
        result = helper.build_tracking_information(resource_with_carrier_no_tracking)

        expect(result).to be_empty
      end

      it 'logs a warning about partial tracking info' do
        expect(Rails.logger).to receive(:warn).with(
          'OracleHealthTrackingHelper: Partial tracking info for resource 66666. ' \
          'Tracking number: missing, carrier: present'
        )
        helper.build_tracking_information(resource_with_carrier_no_tracking)
      end
    end

    context 'with both tracking number and carrier present' do
      let(:resource_with_complete_tracking) do
        {
          'id' => '55555',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Tracking Number', 'valueString' => 'COMPLETE-TRACK' },
                    { 'url' => 'Delivery Service', 'valueString' => 'FEDEX' }
                  ]
                }
              ]
            }
          ]
        }
      end

      it 'does not log any partial tracking warning' do
        expect(Rails.logger).not_to receive(:warn)
        helper.build_tracking_information(resource_with_complete_tracking)
      end
    end
  end
end
