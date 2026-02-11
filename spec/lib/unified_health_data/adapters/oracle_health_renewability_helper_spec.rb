# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/oracle_health_prescription_adapter'

RSpec.describe UnifiedHealthData::Adapters::OracleHealthRenewabilityHelper do
  include ActiveSupport::Testing::TimeHelpers
  include FhirResourceBuilder

  subject { UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter.new }

  describe '#renewable?' do
    context 'when all renewal conditions are met' do
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

      it 'returns true for renewable VA prescription' do
        expect(subject.send(:renewable?, renewable_resource)).to be true
      end

      it 'returns true when expired with remaining refills' do
        resource = fhir_resource(
          status: 'active',
          refills: 5,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        )
        expect(subject.send(:renewable?, resource)).to be true
      end

      it 'returns true when not expired but refills exhausted' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.from_now,
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
        expect(subject.send(:renewable?, resource)).to be true
      end
    end

    context 'with invalid status' do
      it 'returns false when status is completed' do
        resource = fhir_resource(
          status: 'completed',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        )
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns false when status is cancelled' do
        resource = fhir_resource(
          status: 'cancelled',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        )
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns false when status is on-hold' do
        resource = fhir_resource(
          status: 'on-hold',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        )
        expect(subject.send(:renewable?, resource)).to be false
      end
    end

    context 'with non-VA medications' do
      it 'returns false for documented/non-VA medications' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'NV',
          dispense_status: 'completed'
        )
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns false for unclassified medications' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA'
        ).merge('category' => [])
        expect(subject.send(:renewable?, resource)).to be false
      end
    end

    context 'with filtered medication types' do
      it 'returns false for pharmacy charges' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        ).merge('category' => [{ 'coding' => [{ 'code' => 'charge-only' }] }])
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns false for inpatient medications' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        ).merge('category' => [{ 'coding' => [{ 'code' => 'inpatient' }] }])
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns false for clinic administered (outpatient) medications' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        ).merge('category' => [{ 'coding' => [{ 'code' => 'outpatient' }] }])
        expect(subject.send(:renewable?, resource)).to be false
      end
    end

    context 'with dispense history requirements' do
      it 'returns false when no dispenses exist' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA'
        ).merge('contained' => [])
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns true with one completed dispense' do
        resource = fhir_resource(
          status: 'active',
          refills: 0,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        )
        expect(subject.send(:renewable?, resource)).to be true
      end

      it 'returns true with multiple completed dispenses' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA'
        ).merge(
          'contained' => [
            { 'resourceType' => 'MedicationDispense', 'id' => 'dispense-1', 'status' => 'completed' },
            { 'resourceType' => 'MedicationDispense', 'id' => 'dispense-2', 'status' => 'completed' },
            { 'resourceType' => 'MedicationDispense', 'id' => 'dispense-3', 'status' => 'completed' }
          ]
        )
        expect(subject.send(:renewable?, resource)).to be true
      end
    end

    context 'with validity period requirements' do
      it 'returns false when validity period end is missing' do
        resource = fhir_resource(status: 'active', refills: 1, source: 'VA')
        resource['dispenseRequest'].delete('validityPeriod')
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns false when validity period is nil' do
        resource = fhir_resource(status: 'active', refills: 1, source: 'VA')
        resource['dispenseRequest']['validityPeriod'] = nil
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns false when validity period end is nil' do
        resource = fhir_resource(status: 'active', refills: 1, source: 'VA')
        resource['dispenseRequest']['validityPeriod'] = {}
        expect(subject.send(:renewable?, resource)).to be false
      end
    end

    context 'with renewal window (120 days)' do
      it 'returns true when expired 1 day ago' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 1.day.ago,
          source: 'VA',
          dispense_status: 'completed'
        )
        expect(subject.send(:renewable?, resource)).to be true
      end

      it 'returns true when expired 119 days ago' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 119.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        )
        expect(subject.send(:renewable?, resource)).to be true
      end

      it 'returns true at exactly 120 days (boundary)' do
        travel_to Time.zone.parse('2026-01-15T12:00:00Z') do
          resource = fhir_resource(
            status: 'active',
            refills: 1,
            expiration: Time.zone.parse('2025-09-17T12:00:00Z'),
            source: 'VA',
            dispense_status: 'completed'
          )
          expect(subject.send(:renewable?, resource)).to be true
        end
      end

      it 'returns false when expired 121 days ago' do
        travel_to Time.zone.parse('2026-01-15T12:00:00Z') do
          resource = fhir_resource(
            status: 'active',
            refills: 1,
            expiration: Time.zone.parse('2025-09-16T11:59:59Z'),
            source: 'VA',
            dispense_status: 'completed'
          )
          expect(subject.send(:renewable?, resource)).to be false
        end
      end

      it 'returns false when expired 150 days ago' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 150.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        )
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns true when not yet expired (future date)' do
        resource = fhir_resource(
          status: 'active',
          refills: 0,
          expiration: 30.days.from_now,
          source: 'VA',
          dispense_status: 'completed'
        )
        expect(subject.send(:renewable?, resource)).to be true
      end
    end

    context 'with refill and expiration conditions' do
      it 'returns false when not expired and has remaining refills' do
        resource = fhir_resource(
          status: 'active',
          refills: 5,
          expiration: 30.days.from_now,
          source: 'VA',
          dispense_status: 'completed'
        )
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns true when expired regardless of remaining refills' do
        resource = fhir_resource(
          status: 'active',
          refills: 5,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        )
        expect(subject.send(:renewable?, resource)).to be true
      end

      it 'returns true when refills exhausted regardless of expiration' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.from_now,
          source: 'VA'
        ).merge(
          'contained' => [
            { 'resourceType' => 'MedicationDispense', 'status' => 'completed' },
            { 'resourceType' => 'MedicationDispense', 'status' => 'completed' }
          ]
        )
        expect(subject.send(:renewable?, resource)).to be true
      end
    end

    context 'with active processing states' do
      it 'returns false when dispense is in-progress' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'in-progress'
        )
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns false when dispense is in preparation' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'preparation'
        )
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns false when refill requested via web/mobile extension' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        ).merge(
          'extension' => [
            { 'url' => 'http://example.org/fhir/refill-request', 'valueBoolean' => true }
          ]
        )
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns true when refill extension is false' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        ).merge(
          'extension' => [
            { 'url' => 'http://example.org/fhir/refill-request', 'valueBoolean' => false }
          ]
        )
        expect(subject.send(:renewable?, resource)).to be true
      end

      it 'returns true when extension URL does not contain refill-request' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        ).merge(
          'extension' => [
            { 'url' => 'http://example.org/fhir/other-extension', 'valueBoolean' => true }
          ]
        )
        expect(subject.send(:renewable?, resource)).to be true
      end

      it 'returns false when both dispense in-progress and refill extension present' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'in-progress'
        ).merge(
          'extension' => [
            { 'url' => 'http://example.org/fhir/refill-request', 'valueBoolean' => true }
          ]
        )
        expect(subject.send(:renewable?, resource)).to be false
      end
    end

    context 'with edge cases and error handling' do
      it 'returns false for nil resource' do
        expect(subject.send(:renewable?, nil)).to be false
      end

      it 'returns false for non-hash resource' do
        expect(subject.send(:renewable?, 'not a hash')).to be false
      end

      it 'returns false for empty resource' do
        expect(subject.send(:renewable?, {})).to be false
      end

      it 'handles missing dispense status gracefully' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA'
        ).merge(
          'contained' => [
            { 'resourceType' => 'MedicationDispense', 'id' => 'dispense-1', 'status' => 'completed' },
            { 'resourceType' => 'MedicationDispense', 'id' => 'dispense-2' }
          ]
        )
        expect(subject.send(:renewable?, resource)).to be true
      end

      it 'handles missing extension array' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        )
        resource.delete('extension')
        expect(subject.send(:renewable?, resource)).to be true
      end

      it 'handles empty extension array' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA',
          dispense_status: 'completed'
        ).merge('extension' => [])
        expect(subject.send(:renewable?, resource)).to be true
      end
    end

    context 'with complex realistic scenarios' do
      it 'handles prescription with multiple dispenses and mixed statuses' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA'
        ).merge(
          'contained' => [
            { 'resourceType' => 'MedicationDispense', 'status' => 'completed' },
            { 'resourceType' => 'MedicationDispense', 'status' => 'completed' },
            { 'resourceType' => 'MedicationDispense', 'status' => 'cancelled' }
          ]
        )
        expect(subject.send(:renewable?, resource)).to be true
      end

      it 'fails renewal when one dispense is in-progress among completed ones' do
        resource = fhir_resource(
          status: 'active',
          refills: 1,
          expiration: 30.days.ago,
          source: 'VA'
        ).merge(
          'contained' => [
            { 'resourceType' => 'MedicationDispense', 'status' => 'completed' },
            { 'resourceType' => 'MedicationDispense', 'status' => 'in-progress' },
            { 'resourceType' => 'MedicationDispense', 'status' => 'completed' }
          ]
        )
        expect(subject.send(:renewable?, resource)).to be false
      end
    end
  end
end
