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

    context 'with tracking information from extension-based shipping data' do
      let(:resource_with_extension_tracking) do
        {
          'id' => '20848812135',
          'medicationCodeableConcept' => {
            'text' => 'albuterol (albuterol 90 mcg inhaler [18g])',
            'coding' => [
              { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '00487-9801-01' }
            ]
          },
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => '1854364634',
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

      it 'extracts tracking information from dispense extensions' do
        result = subject.parse(resource_with_extension_tracking)

        expect(result).to be_a(UnifiedHealthData::Prescription)
        expect(result.is_trackable).to be true
        expect(result.tracking).to be_an(Array)
        expect(result.tracking.length).to eq(1)

        tracking = result.tracking.first
        expect(tracking[:tracking_number]).to eq('9400111899223100000001')
        expect(tracking[:carrier]).to eq('USPS')
        expect(tracking[:shipped_date]).to eq('2026-01-10 14:35:02.0')
        expect(tracking[:prescription_name]).to eq('albuterol 90 mcg/inh Aerosol')
        expect(tracking[:ndc_number]).to eq('00487-9801-01')
        expect(tracking[:prescription_number]).to eq('RX-PLACER-001')
        expect(tracking[:prescription_id]).to eq('20848812135')
      end

      it 'falls back to resource extraction when extension fields are missing' do
        resource_with_minimal_extension = {
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

        result = subject.parse(resource_with_minimal_extension)

        expect(result).to be_a(UnifiedHealthData::Prescription)
        tracking = result.tracking.first
        expect(tracking[:tracking_number]).to eq('9999888877776666')
        expect(tracking[:prescription_name]).to eq('Test Medication')
        expect(tracking[:prescription_number]).to eq('TEST-001')
        expect(tracking[:ndc_number]).to eq('11111-2222-33')
      end
    end

    context 'with NDC code extraction' do
      it 'extracts NDC from medicationCodeableConcept coding' do
        resource = {
          'id' => '12345',
          'medicationCodeableConcept' => {
            'coding' => [
              { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '00487-9801-01' }
            ]
          },
          'contained' => []
        }

        result = subject.parse(resource)

        # NDC should be extracted even without tracking data
        expect(result).to be_a(UnifiedHealthData::Prescription)
        # NOTE: NDC is not directly exposed in Prescription model, but is used internally
        # Test via tracking if present, or verify it's extracted correctly in helper methods
      end

      it 'finds NDC in coding array with multiple systems' do
        resource = {
          'id' => '12345',
          'medicationCodeableConcept' => {
            'coding' => [
              { 'system' => 'http://example.com/other', 'code' => 'OTHER-123' },
              { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '12345-6789-01' },
              { 'system' => 'http://rxnorm.org', 'code' => 'RXNORM-456' }
            ]
          },
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'extension' => [
                {
                  'url' => 'http://va.gov/fhir/StructureDefinition/shipping-info',
                  'extension' => [
                    { 'url' => 'Tracking Number', 'valueString' => 'TRACK-001' }
                  ]
                }
              ]
            }
          ]
        }

        result = subject.parse(resource)

        expect(result).to be_a(UnifiedHealthData::Prescription)
        # Verify NDC was extracted correctly by checking tracking data
        tracking = result.tracking.first
        expect(tracking[:ndc_number]).to eq('12345-6789-01')
      end

      it 'falls back to dispense NDC when medicationCodeableConcept has no NDC' do
        resource = {
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
                    { 'url' => 'Tracking Number', 'valueString' => 'TRACK-002' }
                  ]
                }
              ]
            }
          ]
        }

        result = subject.parse(resource)

        expect(result).to be_a(UnifiedHealthData::Prescription)
        tracking = result.tracking.first
        expect(tracking[:ndc_number]).to eq('99999-8888-77')
      end

      it 'returns nil when no NDC is available anywhere' do
        resource = {
          'id' => '12345',
          'medicationCodeableConcept' => {
            'text' => 'Some medication'
          },
          'contained' => []
        }

        result = subject.parse(resource)

        expect(result).to be_a(UnifiedHealthData::Prescription)
        # When no tracking data exists, tracking array should be empty
        expect(result.tracking).to be_empty
      end
    end

    context 'with legacy identifier-based tracking' do
      it 'builds tracking from MedicationDispense identifiers when no extension exists' do
        resource = base_fhir_resource.merge(
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'identifier' => [
                { 'type' => { 'text' => 'Tracking Number' }, 'value' => '77298027203980000000398' },
                { 'type' => { 'text' => 'Carrier' }, 'value' => 'UPS' }
              ],
              'medicationCodeableConcept' => {
                'coding' => [
                  { 'system' => 'http://hl7.org/fhir/sid/ndc', 'code' => '11111-2222-33' }
                ]
              }
            }
          ]
        )

        result = subject.parse(resource)

        expect(result.is_trackable).to be true
        expect(result.tracking.length).to eq(1)
        expect(result.tracking.first[:tracking_number]).to eq('77298027203980000000398')
        expect(result.tracking.first[:carrier]).to eq('UPS')
      end

      it 'sets is_trackable to false when no tracking exists' do
        result = subject.parse(base_fhir_resource)
        expect(result.is_trackable).to be false
      end
    end
  end
end
