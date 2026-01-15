# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/models/prescription'
require 'unified_health_data/adapters/oracle_health_prescription_adapter'
require 'lighthouse/facilities/v1/client'

describe UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter do
  include ActiveSupport::Testing::TimeHelpers
  include FhirResourceBuilder

  subject do
    described_class.new
  end

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

      it 'maps active to "expired" when no refills remaining' do
        result = subject.parse(fhir_resource(status: 'active', refills: 0, dispense_status: nil))
        expect(result.refill_status).to eq('expired')
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
end
