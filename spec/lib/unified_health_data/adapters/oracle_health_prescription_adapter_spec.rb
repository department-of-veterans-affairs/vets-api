# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/models/prescription'
require 'unified_health_data/adapters/oracle_health_prescription_adapter'
require 'lighthouse/facilities/v1/client'

describe UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter do
  include ActiveSupport::Testing::TimeHelpers
  include FhirResourceBuilder

  subject { described_class.new }

  before do
    allow(Rails.cache).to receive(:exist?).and_return(false)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
  end

  describe '#parse' do
    context 'with valid resource' do
      it 'returns a UnifiedHealthData::Prescription object with correct id' do
        result = subject.parse(base_fhir_resource)

        expect(result).to be_a(UnifiedHealthData::Prescription)
        expect(result.id).to eq('12345')
      end

      it 'returns nil for nil resource' do
        expect(subject.parse(nil)).to be_nil
      end

      it 'returns nil for resource missing id' do
        resource = base_fhir_resource.except('id')
        expect(subject.parse(resource)).to be_nil
      end

      it 'logs error and returns nil when parsing raises an error' do
        adapter = described_class.new
        allow(adapter).to receive(:extract_refill_date).and_raise(StandardError, 'Test error')
        allow(Rails.logger).to receive(:error)

        result = adapter.parse(base_fhir_resource)

        expect(result).to be_nil
        expect(Rails.logger).to have_received(:error).with('Error parsing Oracle Health prescription: Test error')
      end
    end

    context 'with prescription source classification' do
      it 'sets prescription_source to VA for VA prescriptions' do
        result = subject.parse(fhir_resource(source: 'VA'))
        expect(result.prescription_source).to eq('VA')
      end

      it 'sets prescription_source to NV for documented/non-VA medications' do
        result = subject.parse(fhir_resource(source: 'NV'))
        expect(result.prescription_source).to eq('NV')
      end

      it 'sets prescription_source to NV for unclassified medications' do
        result = subject.parse(base_fhir_resource)
        expect(result.prescription_source).to eq('NV')
      end
    end

    context 'when filtering medications' do
      it 'filters out inpatient medications' do
        resource = base_fhir_resource.merge(
          'category' => [{ 'coding' => [{ 'code' => 'inpatient' }] }]
        )
        expect(subject.parse(resource)).to be_nil
      end

      it 'filters out pharmacy charges medications' do
        resource = base_fhir_resource.merge(
          'category' => [{ 'coding' => [{ 'code' => 'charge-only' }] }]
        )
        expect(subject.parse(resource)).to be_nil
      end
    end

    context 'with refillability' do
      it 'marks VA prescription as refillable when active with refills and not expired' do
        resource = fhir_resource(status: 'active', refills: 5, expiration: 1.year.from_now, source: 'VA')
        result = subject.parse(resource)
        expect(result.is_refillable).to be true
      end

      it 'marks prescription as not refillable when non-VA' do
        result = subject.parse(fhir_resource(refills: 5, source: 'NV'))
        expect(result.is_refillable).to be false
      end

      it 'marks prescription as not refillable when status is not active' do
        result = subject.parse(fhir_resource(status: 'completed'))
        expect(result.is_refillable).to be false
      end

      it 'marks prescription as not refillable when expired' do
        result = subject.parse(fhir_resource(expiration: 1.day.ago))
        expect(result.is_refillable).to be false
      end

      it 'marks prescription as not refillable when no refills remaining' do
        result = subject.parse(fhir_resource(refills: 0))
        expect(result.is_refillable).to be false
      end

      it 'marks prescription as not refillable when most recent dispense is in-progress' do
        result = subject.parse(fhir_resource(refills: 5, dispense_status: 'in-progress'))
        expect(result.is_refillable).to be false
      end

      it 'marks prescription as not refillable when no expiration date exists' do
        resource = fhir_resource(status: 'active', refills: 5)
        resource['dispenseRequest'].delete('validityPeriod')

        result = subject.parse(resource)
        expect(result.is_refillable).to be false
      end
    end

    context 'with renewability' do
      let(:renewable_resource) do
        fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA'
        ).merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'status' => 'completed',
              'whenHandedOver' => '2025-01-15T10:00:00Z'
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-2',
              'status' => 'completed',
              'whenHandedOver' => '2025-01-20T10:00:00Z'
            }
          ]
        )
      end

      it 'marks VA prescription as renewable when all conditions are met' do
        result = subject.parse(renewable_resource)
        expect(result.is_renewable).to be true
      end

      it 'marks prescription as not renewable when status is not active' do
        resource = renewable_resource.merge('status' => 'completed')
        result = subject.parse(resource)
        expect(result.is_renewable).to be false
      end

      it 'marks prescription as not renewable when non-VA medication' do
        result = subject.parse(fhir_resource(source: 'NV'))
        expect(result.is_renewable).to be false
      end

      it 'marks prescription as not renewable when no dispenses exist' do
        resource = renewable_resource.merge('contained' => [])
        result = subject.parse(resource)
        expect(result.is_renewable).to be false
      end

      it 'marks prescription as not renewable when expired more than 120 days ago' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 150.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        )

        result = subject.parse(resource)
        expect(result.is_renewable).to be false
      end
    end

    context 'with status normalization' do
      it 'maps active status to "active" refill_status' do
        result = subject.parse(fhir_resource(status: 'active'))
        expect(result.refill_status).to eq('active')
      end

      it 'maps on-hold status to "providerHold" refill_status' do
        resource = base_fhir_resource.merge('status' => 'on-hold')
        result = subject.parse(resource)
        expect(result.refill_status).to eq('providerHold')
      end

      it 'maps cancelled status to "discontinued" refill_status' do
        resource = base_fhir_resource.merge('status' => 'cancelled')
        result = subject.parse(resource)
        expect(result.refill_status).to eq('discontinued')
      end

      it 'maintains active status to "active" when no refills remaining' do
        result = subject.parse(fhir_resource(status: 'active', refills: 0, dispense_status: nil))
        expect(result.refill_status).to eq('active')
      end

      it 'maps active to "refillinprocess" when most recent dispense is in-progress' do
        result = subject.parse(fhir_resource(status: 'active', dispense_status: 'in-progress'))
        expect(result.refill_status).to eq('refillinprocess')
      end
    end

    context 'with disp_status mapping' do
      it 'maps active VA prescription to "Active" disp_status' do
        result = subject.parse(fhir_resource(status: 'active', source: 'VA'))
        expect(result.disp_status).to eq('Active')
      end

      it 'maps active non-VA prescription to "Active: Non-VA" disp_status' do
        result = subject.parse(fhir_resource(status: 'active', source: 'NV'))
        expect(result.disp_status).to eq('Active: Non-VA')
      end

      it 'maps on-hold to "Active: On hold" disp_status' do
        resource = base_fhir_resource.merge('status' => 'on-hold')
        result = subject.parse(resource)
        expect(result.disp_status).to eq('Active: On hold')
      end

      it 'maps in-progress dispense to "Active: Refill in Process" disp_status' do
        result = subject.parse(fhir_resource(status: 'active', refills: 3, dispense_status: 'in-progress'))
        expect(result.disp_status).to eq('Active: Refill in Process')
      end
    end

    context 'with refill submission tracking using Task resources' do
      it 'sets submitted status when valid Task exists without subsequent dispense' do
        result = subject.parse(fhir_resource_with_task)

        expect(result.refill_status).to eq('submitted')
        expect(result.disp_status).to eq('Active: Submitted')
        expect(result.refill_submit_date).to eq('2025-06-24T21:05:53.000Z')
      end

      it 'ignores failed Task resources' do
        result = subject.parse(fhir_resource_with_task(task_status: 'failed'))

        expect(result.refill_status).to eq('active')
        expect(result.refill_submit_date).to be_nil
      end

      it 'ignores Task with wrong intent' do
        result = subject.parse(fhir_resource_with_task(task_intent: 'refill'))

        expect(result.refill_status).to eq('active')
        expect(result.refill_submit_date).to be_nil
      end

      it 'does not set submitted when dispense occurs after task' do
        resource = fhir_resource_with_task(
          task_date: '2025-06-24T10:00:00.000Z',
          dispenses: [
            {
              status: 'completed',
              when_prepared: '2025-06-24T12:00:00.000Z',
              when_handed_over: '2025-06-24T14:00:00.000Z'
            }
          ]
        )

        result = subject.parse(resource)

        expect(result.refill_status).to eq('active')
        expect(result.refill_submit_date).to be_nil
      end

      it 'sets submitted when dispense occurs before task' do
        resource = fhir_resource_with_task(
          task_date: '2025-06-24T10:00:00.000Z',
          dispenses: [
            {
              status: 'completed',
              when_prepared: '2025-06-20T12:00:00.000Z',
              when_handed_over: '2025-06-20T14:00:00.000Z'
            }
          ]
        )

        result = subject.parse(resource)

        expect(result.refill_status).to eq('submitted')
        expect(result.refill_submit_date).to eq('2025-06-24T10:00:00.000Z')
      end
    end

    context 'with tracking information' do
      it 'builds tracking when MedicationDispense has tracking identifiers' do
        resource = base_fhir_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => '21142623',
              'identifier' => [
                { 'type' => { 'text' => 'Tracking Number' }, 'value' => '77298027203980000000398' },
                { 'type' => { 'text' => 'Carrier' }, 'value' => 'UPS' }
              ]
            }
          ]
        )

        result = subject.parse(resource)

        expect(result.is_trackable).to be true
        expect(result.tracking.length).to eq(1)
        expect(result.tracking.first[:tracking_number]).to eq('77298027203980000000398')
      end

      it 'sets is_trackable to false when no tracking number exists' do
        result = subject.parse(base_fhir_resource)
        expect(result.is_trackable).to be false
      end
    end
  end

  describe '#extract_tracking_from_dispense_extensions' do
    let(:resource) { { 'id' => '12345' } }

    context 'when dispense has shipping-info extension with tracking data' do
      let(:dispense) do
        {
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
      end

      it 'extracts tracking information from extension array' do
        result = adapter.send(:extract_tracking_from_dispense_extensions, resource, dispense)

        expect(result).to be_a(Hash)
        expect(result[:tracking_number]).to eq('9400111899223100000001')
        expect(result[:carrier]).to eq('USPS')
        expect(result[:shipped_date]).to eq('2026-01-10 14:35:02.0')
        expect(result[:prescription_name]).to eq('albuterol 90 mcg/inh Aerosol')
        expect(result[:ndc_number]).to eq('00487-9801-01')
        expect(result[:prescription_number]).to eq('RX-PLACER-001')
        expect(result[:prescription_id]).to eq('12345')
        expect(result[:other_prescriptions]).to eq([])
      end
    end

    context 'when dispense has no extension array' do
      let(:dispense) { {} }

      it 'returns nil' do
        result = adapter.send(:extract_tracking_from_dispense_extensions, resource, dispense)
        expect(result).to be_nil
      end
    end

    context 'when dispense has empty extension array' do
      let(:dispense) { { 'extension' => [] } }

      it 'returns nil' do
        result = adapter.send(:extract_tracking_from_dispense_extensions, resource, dispense)
        expect(result).to be_nil
      end
    end

    context 'when dispense has extensions but no shipping-info extension' do
      let(:dispense) do
        {
          'extension' => [
            {
              'url' => 'http://example.com/other-extension',
              'extension' => [
                { 'url' => 'Some Field', 'valueString' => 'some value' }
              ]
            }
          ]
        }
      end

      it 'returns nil' do
        result = adapter.send(:extract_tracking_from_dispense_extensions, resource, dispense)
        expect(result).to be_nil
      end
    end

    context 'when shipping-info extension has no nested extensions' do
      let(:dispense) do
        {
          'extension' => [
            {
              'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
              'extension' => []
            }
          ]
        }
      end

      it 'returns nil' do
        result = adapter.send(:extract_tracking_from_dispense_extensions, resource, dispense)
        expect(result).to be_nil
      end
    end

    context 'when shipping-info extension has no tracking number' do
      let(:dispense) do
        {
          'extension' => [
            {
              'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
              'extension' => [
                { 'url' => 'Delivery Service', 'valueString' => 'USPS' },
                { 'url' => 'Shipped Date', 'valueString' => '2026-01-10 14:35:02.0' }
              ]
            }
          ]
        }
      end

      it 'returns nil because tracking number is required' do
        result = adapter.send(:extract_tracking_from_dispense_extensions, resource, dispense)
        expect(result).to be_nil
      end
    end

    context 'when shipping-info has tracking number but other fields are missing' do
      let(:dispense) do
        {
          'extension' => [
            {
              'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
              'extension' => [
                { 'url' => 'Tracking Number', 'valueString' => '9400111899223100000001' }
              ]
            }
          ]
        }
      end

      before do
        allow(adapter).to receive(:extract_prescription_name).and_return('Test Medication')
        allow(adapter).to receive(:extract_prescription_number).and_return('TEST-001')
        allow(adapter).to receive(:extract_ndc_from_resource).and_return('12345-6789-01')
      end

      it 'falls back to resource extraction methods for missing fields' do
        result = adapter.send(:extract_tracking_from_dispense_extensions, resource, dispense)

        expect(result).to be_a(Hash)
        expect(result[:tracking_number]).to eq('9400111899223100000001')
        expect(result[:carrier]).to be_nil
        expect(result[:shipped_date]).to be_nil
        expect(result[:prescription_name]).to eq('Test Medication')
        expect(result[:prescription_number]).to eq('TEST-001')
        expect(result[:ndc_number]).to eq('12345-6789-01')
      end
    end
  end

  describe '#find_extension_value_by_url' do
    let(:extensions) do
      [
        { 'url' => 'http://example.com/tracking/Tracking Number', 'valueString' => '123456' },
        { 'url' => 'http://example.com/shipping/Carrier', 'valueString' => 'USPS' },
        { 'url' => 'http://example.com/other', 'valueString' => 'other value' }
      ]
    end

    context 'when extension with matching URL suffix exists' do
      it 'returns the valueString' do
        result = adapter.send(:find_extension_value_by_url, extensions, 'Tracking Number')
        expect(result).to eq('123456')
      end

      it 'matches by URL suffix' do
        result = adapter.send(:find_extension_value_by_url, extensions, 'Carrier')
        expect(result).to eq('USPS')
      end
    end

    context 'when extension with URL suffix does not exist' do
      it 'returns nil' do
        result = adapter.send(:find_extension_value_by_url, extensions, 'Nonexistent Field')
        expect(result).to be_nil
      end
    end

    context 'when extensions array is empty' do
      it 'returns nil' do
        result = adapter.send(:find_extension_value_by_url, [], 'Tracking Number')
        expect(result).to be_nil
      end
    end

    context 'when extension has no valueString' do
      let(:extensions) do
        [
          { 'url' => 'http://example.com/tracking/Tracking Number' }
        ]
      end

      it 'returns nil' do
        result = adapter.send(:find_extension_value_by_url, extensions, 'Tracking Number')
        expect(result).to be_nil
      end
    end

    context 'when extension url is nil' do
      let(:extensions) do
        [
          { 'url' => nil, 'valueString' => '123456' }
        ]
      end

      it 'returns nil' do
        result = adapter.send(:find_extension_value_by_url, extensions, 'Tracking Number')
        expect(result).to be_nil
      end
    end
  end

  describe '#extract_ndc_from_resource' do
    context 'when medicationCodeableConcept has NDC coding' do
      let(:resource) do
        {
          'medicationCodeableConcept' => {
            'coding' => [
              { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '00487-9801-01' }
            ]
          }
        }
      end

      it 'returns the NDC code' do
        result = adapter.send(:extract_ndc_from_resource, resource)
        expect(result).to eq('00487-9801-01')
      end
    end

    context 'when medicationCodeableConcept has multiple codings' do
      let(:resource) do
        {
          'medicationCodeableConcept' => {
            'coding' => [
              { 'system' => 'http://example.com/other', 'code' => 'OTHER-123' },
              { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '12345-6789-01' },
              { 'system' => 'http://rxnorm.org', 'code' => 'RXNORM-456' }
            ]
          }
        }
      end

      it 'returns the NDC code from the NDC system' do
        result = adapter.send(:extract_ndc_from_resource, resource)
        expect(result).to eq('12345-6789-01')
      end
    end

    context 'when medicationCodeableConcept has no NDC coding' do
      let(:resource) do
        {
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
              }
            }
          ]
        }
      end

      it 'falls back to most recent dispense' do
        allow(adapter).to receive(:extract_ndc_number).and_return('99999-8888-77')
        result = adapter.send(:extract_ndc_from_resource, resource)
        expect(result).to eq('99999-8888-77')
      end
    end

    context 'when medicationCodeableConcept has no coding array' do
      let(:resource) do
        {
          'medicationCodeableConcept' => {
            'text' => 'Some medication'
          },
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'whenHandedOver' => '2025-11-17T21:35:02.000Z'
            }
          ]
        }
      end

      it 'falls back to dispense extraction' do
        allow(adapter).to receive(:extract_ndc_number).and_return('11111-2222-33')
        result = adapter.send(:extract_ndc_from_resource, resource)
        expect(result).to eq('11111-2222-33')
      end
    end

    context 'when no NDC is available anywhere' do
      let(:resource) do
        {
          'medicationCodeableConcept' => {
            'text' => 'Some medication'
          }
        }
      end

      it 'returns nil' do
        allow(adapter).to receive(:find_most_recent_medication_dispense).and_return(nil)
        result = adapter.send(:extract_ndc_from_resource, resource)
        expect(result).to be_nil
      end
    end

    context 'when NDC coding exists but has no code field' do
      let(:resource) do
        {
          'medicationCodeableConcept' => {
            'coding' => [
              { 'system' => 'http://hl7.org/fhir/sid/ndc' }
            ]
          }
        }
      end

      it 'returns nil and falls back to dispense' do
        allow(adapter).to receive(:find_most_recent_medication_dispense).and_return(nil)
        result = adapter.send(:extract_ndc_from_resource, resource)
        expect(result).to be_nil
      end
    end
  end

  describe '#build_tracking_information integration' do
    context 'when dispenses have extension-based tracking' do
      let(:resource) do
        {
          'id' => '20848812135',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Tracking Number', 'valueString' => '9400111899223100000001' },
                    { 'url' => 'Delivery Service', 'valueString' => 'USPS' }
                  ]
                }
              ]
            }
          ]
        }
      end

      it 'uses extension-based extraction' do
        result = adapter.send(:build_tracking_information, resource)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result.first[:tracking_number]).to eq('9400111899223100000001')
        expect(result.first[:carrier]).to eq('USPS')
      end
    end

    context 'when dispenses have legacy identifier-based tracking' do
      let(:resource) do
        {
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'identifier' => [
                { 'type' => { 'text' => 'Tracking Number' }, 'value' => 'LEGACY-123' }
              ]
            }
          ]
        }
      end

      it 'falls back to identifier-based extraction' do
        allow(adapter).to receive(:extract_prescription_name).and_return('Test Med')
        allow(adapter).to receive(:extract_prescription_number).and_return('TEST-001')
        allow(adapter).to receive(:extract_ndc_number).and_return('12345-6789-01')

        result = adapter.send(:build_tracking_information, resource)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result.first[:tracking_number]).to eq('LEGACY-123')
      end
    end

    context 'when no tracking information is available' do
      let(:resource) do
        {
          'id' => '12345',
          'contained' => [
            { 'resourceType' => 'MedicationDispense' }
          ]
        }
      end

      it 'returns empty array' do
        result = adapter.send(:build_tracking_information, resource)
        expect(result).to eq([])
      end
    end
  end
end
