# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/oracle_health_prescription_adapter'

RSpec.describe UnifiedHealthData::Adapters::OracleHealthRenewabilityHelper do
  include ActiveSupport::Testing::TimeHelpers

  subject { UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter.new }

  # Base renewable resource: active status, VA Prescription classification
  # (reportedBoolean=false, intent='order', community + discharge categories),
  # has dispenses, validity period exists, within 120 days, refills exhausted OR expired,
  # no active processing
  #
  # This resource represents an EXPIRED prescription (validity period ended 30 days ago)
  # with zero refills remaining - both conditions make it renewable
  #
  # Refill calculation: numberOfRepeatsAllowed - (dispenses_completed - 1)
  # With numberOfRepeatsAllowed=1 and 2 completed dispenses: 1 - (2-1) = 0 remaining
  let(:base_renewable_resource) do
    {
      'status' => 'active',
      'reportedBoolean' => false,
      'intent' => 'order',
      'category' => [
        { 'coding' => [{ 'code' => 'community' }] },
        { 'coding' => [{ 'code' => 'discharge' }] }
      ],
      'dispenseRequest' => {
        'numberOfRepeatsAllowed' => 1,
        'validityPeriod' => {
          'end' => 30.days.ago.utc.iso8601
        }
      },
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
    }
  end

  # ============================================================================
  # INTEGRATION TESTS: #renewable? method
  # High-level tests demonstrating each gate as a filter in the renewability logic
  # ============================================================================
  describe '#renewable?' do
    describe 'when all conditions are met' do
      it 'returns true for renewable VA Prescription (community + discharge)' do
        expect(subject.send(:renewable?, base_renewable_resource)).to be true
      end

      it 'returns false for renewable Clinic Administered medication (outpatient)' do
        resource = base_renewable_resource.merge(
          'category' => [{ 'coding' => [{ 'code' => 'outpatient' }] }]
        )
        expect(subject.send(:renewable?, resource)).to be false
      end
    end

    describe 'Gate 1: Status must be active' do
      it 'returns false when status is not active' do
        resource = base_renewable_resource.merge('status' => 'completed')
        expect(subject.send(:renewable?, resource)).to be false
      end
    end

    describe 'Gate 2: Medication classification' do
      it 'returns false for Documented/Non-VA medications' do
        resource = base_renewable_resource.merge(
          'reportedBoolean' => true,
          'intent' => 'plan',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'patientspecified' }] }
          ]
        )
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns false for unclassified medications' do
        resource = base_renewable_resource.merge('category' => [])
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns false for pharmacy charges' do
        resource = base_renewable_resource.merge(
          'category' => [{ 'coding' => [{ 'code' => 'charge-only' }] }]
        )
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns false for inpatient medications' do
        resource = base_renewable_resource.merge(
          'category' => [{ 'coding' => [{ 'code' => 'inpatient' }] }]
        )
        expect(subject.send(:renewable?, resource)).to be false
      end
    end

    describe 'Gate 3: Must have at least one dispense' do
      it 'returns false when no dispenses exist' do
        resource = base_renewable_resource.merge('contained' => [])
        expect(subject.send(:renewable?, resource)).to be false
      end
    end

    describe 'Gate 4: Validity period end date must exist' do
      it 'returns false when validity period end is missing' do
        resource = base_renewable_resource.merge(
          'dispenseRequest' => { 'numberOfRepeatsAllowed' => 1, 'validityPeriod' => {} }
        )
        expect(subject.send(:renewable?, resource)).to be false
      end
    end

    describe 'Gate 5: Within 120 days of validity period end' do
      it 'returns false when expired more than 120 days ago' do
        travel_to Time.zone.parse('2026-01-08 12:00:00 UTC') do
          # Expiration was 121 days ago
          expiration_date = Time.zone.parse('2025-09-09 00:00:00 UTC').iso8601
          resource = base_renewable_resource.merge(
            'dispenseRequest' => {
              'numberOfRepeatsAllowed' => 1,
              'validityPeriod' => { 'end' => expiration_date }
            }
          )
          expect(subject.send(:renewable?, resource)).to be false
        end
      end
    end

    describe 'Gate 6: Refills exhausted OR prescription expired' do
      it 'returns false when refills remain and prescription is NOT expired' do
        resource = base_renewable_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 5,
            'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
          }
        )
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns true when refills remain but prescription IS expired' do
        resource = base_renewable_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 5,
            'validityPeriod' => { 'end' => 30.days.ago.utc.iso8601 }
          }
        )
        expect(subject.send(:renewable?, resource)).to be true
      end
    end

    describe 'Gate 7: No active processing' do
      it 'returns false when a dispense is in-progress' do
        resource = base_renewable_resource.merge(
          'contained' => [
            { 'resourceType' => 'MedicationDispense', 'id' => 'dispense-1', 'status' => 'in-progress' }
          ]
        )
        expect(subject.send(:renewable?, resource)).to be false
      end

      it 'returns false when refill requested via web/mobile extension' do
        resource = base_renewable_resource.merge(
          'extension' => [
            { 'url' => 'http://example.org/fhir/refill-request', 'valueBoolean' => true }
          ]
        )
        expect(subject.send(:renewable?, resource)).to be false
      end
    end

    describe 'error handling' do
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
        resource = base_renewable_resource.merge(
          'contained' => [
            { 'resourceType' => 'MedicationDispense', 'id' => 'dispense-1', 'status' => 'completed' },
            { 'resourceType' => 'MedicationDispense', 'id' => 'dispense-2' }
          ]
        )
        # nil status is not 'in-progress' or 'preparation', and expired rx is renewable
        expect(subject.send(:renewable?, resource)).to be true
      end
    end
  end

  # ============================================================================
  # UNIT TESTS: Private Helper Methods
  # Detailed tests for individual methods with full permutation coverage
  # ============================================================================
  describe 'private helper methods' do
    describe '#validity_period_end_exists?' do
      it 'returns true when validityPeriod end exists' do
        expect(subject.send(:validity_period_end_exists?, base_renewable_resource)).to be true
      end

      it 'returns false when validityPeriod end is nil' do
        resource = base_renewable_resource.merge(
          'dispenseRequest' => { 'validityPeriod' => {} }
        )
        expect(subject.send(:validity_period_end_exists?, resource)).to be false
      end

      it 'returns false when validityPeriod is nil' do
        resource = base_renewable_resource.merge('dispenseRequest' => {})
        expect(subject.send(:validity_period_end_exists?, resource)).to be false
      end

      it 'returns false when dispenseRequest is nil' do
        resource = base_renewable_resource.except('dispenseRequest')
        expect(subject.send(:validity_period_end_exists?, resource)).to be false
      end
    end

    describe '#within_renewal_window?' do
      it 'returns true when expired less than 120 days ago' do
        expect(subject.send(:within_renewal_window?, base_renewable_resource)).to be true
      end

      it 'returns true at exactly 120 days (boundary)' do
        travel_to Time.zone.parse('2026-01-15T12:00:00Z') do
          resource = base_renewable_resource.deep_merge(
            'dispenseRequest' => {
              'validityPeriod' => { 'end' => '2025-09-17T12:00:00Z' } # exactly 120 days before
            }
          )
          expect(subject.send(:within_renewal_window?, resource)).to be true
        end
      end

      it 'returns false when expired more than 120 days ago' do
        travel_to Time.zone.parse('2026-01-15T12:00:00Z') do
          resource = base_renewable_resource.deep_merge(
            'dispenseRequest' => {
              'validityPeriod' => { 'end' => '2025-09-16T11:59:59Z' } # 121 days before
            }
          )
          expect(subject.send(:within_renewal_window?, resource)).to be false
        end
      end

      it 'returns true when prescription has not yet expired (future date)' do
        resource = base_renewable_resource.deep_merge(
          'dispenseRequest' => {
            'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
          }
        )
        expect(subject.send(:within_renewal_window?, resource)).to be true
      end

      it 'returns false when expiration date is nil' do
        resource = base_renewable_resource.deep_merge(
          'dispenseRequest' => { 'validityPeriod' => { 'end' => nil } }
        )
        expect(subject.send(:within_renewal_window?, resource)).to be false
      end
    end

    # NOTE: prescription_expired? is now defined in FhirHelpers and shared across modules.
    # These tests verify the method works correctly in the context of the renewability helper.
    describe '#prescription_expired?' do
      it 'returns true when validity period end is in the past' do
        expect(subject.send(:prescription_expired?, base_renewable_resource)).to be true
      end

      it 'returns false when validity period end is in the future' do
        resource = base_renewable_resource.merge(
          'dispenseRequest' => {
            'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
          }
        )
        expect(subject.send(:prescription_expired?, resource)).to be false
      end

      it 'returns false when validity period end is nil' do
        resource = base_renewable_resource.merge(
          'dispenseRequest' => { 'validityPeriod' => {} }
        )
        expect(subject.send(:prescription_expired?, resource)).to be false
      end
    end

    describe '#refills_exhausted_or_expired?' do
      context 'when prescription is expired' do
        it 'returns true regardless of refills remaining' do
          resource = base_renewable_resource.merge(
            'dispenseRequest' => {
              'numberOfRepeatsAllowed' => 5,
              'validityPeriod' => { 'end' => 30.days.ago.utc.iso8601 }
            }
          )
          expect(subject.send(:refills_exhausted_or_expired?, resource)).to be true
        end

        it 'returns true with zero refills remaining' do
          expect(subject.send(:refills_exhausted_or_expired?, base_renewable_resource)).to be true
        end
      end

      context 'when prescription is not expired' do
        it 'returns true when zero refills remaining' do
          resource = base_renewable_resource.merge(
            'dispenseRequest' => {
              'numberOfRepeatsAllowed' => 1,
              'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
            }
          )
          expect(subject.send(:refills_exhausted_or_expired?, resource)).to be true
        end

        it 'returns false when refills are remaining' do
          resource = base_renewable_resource.merge(
            'dispenseRequest' => {
              'numberOfRepeatsAllowed' => 5,
              'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
            }
          )
          expect(subject.send(:refills_exhausted_or_expired?, resource)).to be false
        end
      end
    end

    describe '#active_processing?' do
      it 'returns false when all dispenses are completed' do
        expect(subject.send(:active_processing?, base_renewable_resource)).to be false
      end

      it 'returns true when any dispense is in-progress' do
        resource = base_renewable_resource.merge(
          'contained' => [
            { 'resourceType' => 'MedicationDispense', 'status' => 'in-progress' }
          ]
        )
        expect(subject.send(:active_processing?, resource)).to be true
      end

      it 'returns true when any dispense is in preparation' do
        resource = base_renewable_resource.merge(
          'contained' => [
            { 'resourceType' => 'MedicationDispense', 'status' => 'preparation' }
          ]
        )
        expect(subject.send(:active_processing?, resource)).to be true
      end

      it 'returns false when dispense is completed' do
        resource = base_renewable_resource.merge(
          'contained' => [
            { 'resourceType' => 'MedicationDispense', 'status' => 'completed' }
          ]
        )
        expect(subject.send(:active_processing?, resource)).to be false
      end

      it 'returns true when refill-request extension with valueBoolean=true' do
        resource = base_renewable_resource.merge(
          'extension' => [
            { 'url' => 'http://example.org/fhir/refill-request', 'valueBoolean' => true }
          ]
        )
        expect(subject.send(:active_processing?, resource)).to be true
      end

      it 'returns false when refill-request extension with valueBoolean=false' do
        resource = base_renewable_resource.merge(
          'extension' => [
            { 'url' => 'http://example.org/fhir/refill-request', 'valueBoolean' => false }
          ]
        )
        expect(subject.send(:active_processing?, resource)).to be false
      end

      it 'returns false when extension is nil' do
        resource = base_renewable_resource.except('extension')
        expect(subject.send(:active_processing?, resource)).to be false
      end

      it 'returns true when both dispense in-progress and refill-request extension present' do
        resource = base_renewable_resource.merge(
          'contained' => [
            { 'resourceType' => 'MedicationDispense', 'id' => 'dispense-1', 'status' => 'in-progress' }
          ],
          'extension' => [
            { 'url' => 'http://example.org/fhir/refill-request', 'valueBoolean' => true }
          ]
        )
        expect(subject.send(:active_processing?, resource)).to be true
      end
    end

    describe '#refill_requested_via_web_or_mobile?' do
      it 'returns true when refill-request extension has valueBoolean=true' do
        resource = base_renewable_resource.merge(
          'extension' => [
            { 'url' => 'http://example.org/fhir/refill-request', 'valueBoolean' => true }
          ]
        )
        expect(subject.send(:refill_requested_via_web_or_mobile?, resource)).to be true
      end

      it 'returns false when refill-request extension has valueBoolean=false' do
        resource = base_renewable_resource.merge(
          'extension' => [
            { 'url' => 'http://example.org/fhir/refill-request', 'valueBoolean' => false }
          ]
        )
        expect(subject.send(:refill_requested_via_web_or_mobile?, resource)).to be false
      end

      it 'returns false when no extension present' do
        resource = base_renewable_resource.except('extension')
        expect(subject.send(:refill_requested_via_web_or_mobile?, resource)).to be false
      end

      it 'returns false when extension array is empty' do
        resource = base_renewable_resource.merge('extension' => [])
        expect(subject.send(:refill_requested_via_web_or_mobile?, resource)).to be false
      end

      it 'returns false when extension URL does not contain refill-request' do
        resource = base_renewable_resource.merge(
          'extension' => [
            { 'url' => 'http://example.org/fhir/other-extension', 'valueBoolean' => true }
          ]
        )
        expect(subject.send(:refill_requested_via_web_or_mobile?, resource)).to be false
      end
    end
  end
end
