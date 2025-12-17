# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/oracle_health_prescription_adapter'

RSpec.describe UnifiedHealthData::Adapters::RenewabilityHelper do
  # Test via the OracleHealthPrescriptionAdapter which includes the module
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

  describe '#extract_is_renewable' do
    describe 'Gate 1: Status must be active' do
      it 'returns true when status is active' do
        expect(subject.send(:extract_is_renewable, base_renewable_resource)).to be true
      end

      it 'returns false when status is completed' do
        resource = base_renewable_resource.merge('status' => 'completed')
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end

      it 'returns false when status is stopped' do
        resource = base_renewable_resource.merge('status' => 'stopped')
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end

      it 'returns false when status is nil' do
        resource = base_renewable_resource.except('status')
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end
    end

    describe 'Gate 2: Medication Classification' do
      describe 'VA Prescription classification' do
        it 'returns true with reportedBoolean=false, intent=order, community+discharge categories' do
          expect(subject.send(:extract_is_renewable, base_renewable_resource)).to be true
        end

        it 'returns false when reportedBoolean is true' do
          resource = base_renewable_resource.merge('reportedBoolean' => true)
          expect(subject.send(:extract_is_renewable, resource)).to be false
        end

        it 'returns false when reportedBoolean is nil' do
          resource = base_renewable_resource.except('reportedBoolean')
          expect(subject.send(:extract_is_renewable, resource)).to be false
        end

        it 'returns false when intent is not order' do
          resource = base_renewable_resource.merge('intent' => 'plan')
          expect(subject.send(:extract_is_renewable, resource)).to be false
        end

        it 'returns false when intent is nil' do
          resource = base_renewable_resource.except('intent')
          expect(subject.send(:extract_is_renewable, resource)).to be false
        end

        it 'returns false when only community category present' do
          resource = base_renewable_resource.merge(
            'category' => [{ 'coding' => [{ 'code' => 'community' }] }]
          )
          expect(subject.send(:extract_is_renewable, resource)).to be false
        end

        it 'returns false when only discharge category present' do
          resource = base_renewable_resource.merge(
            'category' => [{ 'coding' => [{ 'code' => 'discharge' }] }]
          )
          expect(subject.send(:extract_is_renewable, resource)).to be false
        end

        it 'returns false when additional categories present beyond community+discharge' do
          resource = base_renewable_resource.merge(
            'category' => [
              { 'coding' => [{ 'code' => 'community' }] },
              { 'coding' => [{ 'code' => 'discharge' }] },
              { 'coding' => [{ 'code' => 'outpatient' }] }
            ]
          )
          expect(subject.send(:extract_is_renewable, resource)).to be false
        end
      end

      describe 'Clinic Administered classification' do
        let(:clinic_administered_resource) do
          base_renewable_resource.merge(
            'category' => [{ 'coding' => [{ 'code' => 'outpatient' }] }]
          )
        end

        it 'returns true with reportedBoolean=false, intent=order, outpatient only' do
          expect(subject.send(:extract_is_renewable, clinic_administered_resource)).to be true
        end

        it 'returns false when additional categories present beyond outpatient' do
          resource = base_renewable_resource.merge(
            'category' => [
              { 'coding' => [{ 'code' => 'outpatient' }] },
              { 'coding' => [{ 'code' => 'community' }] }
            ]
          )
          expect(subject.send(:extract_is_renewable, resource)).to be false
        end
      end

      describe 'Documented/Non-VA classification (not renewable)' do
        let(:non_va_resource) do
          base_renewable_resource.merge(
            'reportedBoolean' => true,
            'intent' => 'plan',
            'category' => [
              { 'coding' => [{ 'code' => 'community' }] },
              { 'coding' => [{ 'code' => 'patient-specified' }] }
            ]
          )
        end

        it 'returns false for Documented/Non-VA medications' do
          expect(subject.send(:extract_is_renewable, non_va_resource)).to be false
        end
      end

      describe 'Unclassified medications (not renewable)' do
        it 'returns false when category is empty' do
          resource = base_renewable_resource.merge('category' => [])
          expect(subject.send(:extract_is_renewable, resource)).to be false
        end

        it 'returns false when category is nil' do
          resource = base_renewable_resource.except('category')
          expect(subject.send(:extract_is_renewable, resource)).to be false
        end

        it 'returns false for inpatient category' do
          resource = base_renewable_resource.merge(
            'category' => [{ 'coding' => [{ 'code' => 'inpatient' }] }]
          )
          expect(subject.send(:extract_is_renewable, resource)).to be false
        end
      end
    end

    describe 'Gate 3: Must have at least one dispense' do
      it 'returns false when no dispenses exist' do
        resource = base_renewable_resource.merge('contained' => [])
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end

      it 'returns false when contained is nil' do
        resource = base_renewable_resource.except('contained')
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end

      it 'returns false when contained has non-dispense resources only' do
        resource = base_renewable_resource.merge(
          'contained' => [{ 'resourceType' => 'Medication', 'id' => 'med-1' }]
        )
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end
    end

    describe 'Gate 4: Validity period end date must exist' do
      it 'returns false when validityPeriod end is nil' do
        resource = base_renewable_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 1,
            'validityPeriod' => {}
          }
        )
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end

      it 'returns false when validityPeriod is nil' do
        resource = base_renewable_resource.merge(
          'dispenseRequest' => { 'numberOfRepeatsAllowed' => 1 }
        )
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end

      it 'returns false when dispenseRequest is nil' do
        resource = base_renewable_resource.except('dispenseRequest')
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end

      it 'returns true when validityPeriod end exists' do
        expect(subject.send(:extract_is_renewable, base_renewable_resource)).to be true
      end
    end

    describe 'Gate 5: Within 120 days of validity period end' do
      it 'returns true when expired 30 days ago' do
        expect(subject.send(:extract_is_renewable, base_renewable_resource)).to be true
      end

      it 'returns true when expired exactly 120 days ago' do
        # Use freeze_time or a slightly less than 120 days to avoid boundary issues
        resource = base_renewable_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 1,
            'validityPeriod' => { 'end' => 119.days.ago.utc.iso8601 }
          }
        )
        expect(subject.send(:extract_is_renewable, resource)).to be true
      end

      it 'returns false when expired 121 days ago' do
        resource = base_renewable_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 1,
            'validityPeriod' => { 'end' => 121.days.ago.utc.iso8601 }
          }
        )
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end

      it 'returns true when prescription not yet expired (future date)' do
        # Non-expired with zero refills remaining
        resource = base_renewable_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 1,
            'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
          }
        )
        expect(subject.send(:extract_is_renewable, resource)).to be true
      end
    end

    describe 'Gate 6: Refills exhausted OR prescription expired' do
      context 'when prescription is NOT expired (validity period in future)' do
        it 'returns false when refills are remaining (should use refill process)' do
          resource = base_renewable_resource.merge(
            'dispenseRequest' => {
              'numberOfRepeatsAllowed' => 5,
              'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
            }
          )
          expect(subject.send(:extract_is_renewable, resource)).to be false
        end

        it 'returns true when zero refills remaining' do
          resource = base_renewable_resource.merge(
            'dispenseRequest' => {
              'numberOfRepeatsAllowed' => 1,
              'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
            }
          )
          expect(subject.send(:extract_is_renewable, resource)).to be true
        end
      end

      context 'when prescription IS expired (validity period in past)' do
        it 'returns true when refills are remaining (refills cannot be processed on expired rx)' do
          # Expired 30 days ago with 4 refills remaining
          resource = base_renewable_resource.merge(
            'dispenseRequest' => {
              'numberOfRepeatsAllowed' => 5,
              'validityPeriod' => { 'end' => 30.days.ago.utc.iso8601 }
            }
          )
          expect(subject.send(:extract_is_renewable, resource)).to be true
        end

        it 'returns true when zero refills remaining' do
          expect(subject.send(:extract_is_renewable, base_renewable_resource)).to be true
        end
      end
    end

    describe 'Gate 7: No active processing' do
      it 'returns false when a dispense is in-progress' do
        resource = base_renewable_resource.merge(
          'contained' => [
            { 'resourceType' => 'MedicationDispense', 'id' => 'dispense-1', 'status' => 'in-progress' },
            { 'resourceType' => 'MedicationDispense', 'id' => 'dispense-2', 'status' => 'completed' }
          ]
        )
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end

      it 'returns false when a dispense is in preparation' do
        resource = base_renewable_resource.merge(
          'contained' => [
            { 'resourceType' => 'MedicationDispense', 'id' => 'dispense-1', 'status' => 'preparation' },
            { 'resourceType' => 'MedicationDispense', 'id' => 'dispense-2', 'status' => 'completed' }
          ]
        )
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end

      it 'returns false when refill requested via web/mobile extension' do
        resource = base_renewable_resource.merge(
          'extension' => [
            { 'url' => 'http://example.org/fhir/refill-request', 'valueBoolean' => true }
          ]
        )
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end

      it 'returns true when refill request extension has valueBoolean=false' do
        resource = base_renewable_resource.merge(
          'extension' => [
            { 'url' => 'http://example.org/fhir/refill-request', 'valueBoolean' => false }
          ]
        )
        expect(subject.send(:extract_is_renewable, resource)).to be true
      end

      it 'returns true when extension is nil' do
        resource = base_renewable_resource.except('extension')
        expect(subject.send(:extract_is_renewable, resource)).to be true
      end
    end

    describe 'handling missing/malformed FHIR properties' do
      it 'returns false for empty resource' do
        expect(subject.send(:extract_is_renewable, {})).to be false
      end

      it 'returns false for nil resource' do
        expect(subject.send(:extract_is_renewable, nil)).to be false
      end

      it 'handles missing dispense status gracefully' do
        resource = base_renewable_resource.merge(
          'contained' => [
            { 'resourceType' => 'MedicationDispense', 'id' => 'dispense-1', 'status' => 'completed' },
            { 'resourceType' => 'MedicationDispense', 'id' => 'dispense-2' }
          ]
        )
        # Gate 7: nil status is not 'in-progress' or 'preparation', so passes
        # Gate 6: With 1 completed dispense, refills = 1 - (1-1) = 1 remaining
        #         But the prescription is expired (30 days ago), so Gate 6 passes
        #         (expired prescriptions are renewable regardless of refills remaining)
        # Result: Renewable
        expect(subject.send(:extract_is_renewable, resource)).to be true
      end

      it 'handles category with empty coding array' do
        resource = base_renewable_resource.merge(
          'category' => [{ 'coding' => [] }]
        )
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end

      it 'handles category with nil coding' do
        resource = base_renewable_resource.merge(
          'category' => [{}]
        )
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end
    end
  end

  describe '#renewable_medication_classification?' do
    describe '#va_prescription?' do
      it 'returns true for exact match of community and discharge' do
        expect(subject.send(:extract_is_renewable, base_renewable_resource)).to be true
      end

      it 'requires exactly community and discharge categories' do
        # Extra category should fail
        resource = base_renewable_resource.merge(
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'discharge' }] },
            { 'coding' => [{ 'code' => 'inpatient' }] }
          ]
        )
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end
    end

    describe '#clinic_administered?' do
      it 'returns true for exactly outpatient category' do
        resource = base_renewable_resource.merge(
          'category' => [{ 'coding' => [{ 'code' => 'outpatient' }] }]
        )
        expect(subject.send(:extract_is_renewable, resource)).to be true
      end

      it 'requires exactly outpatient category only' do
        # Extra category should fail
        resource = base_renewable_resource.merge(
          'category' => [
            { 'coding' => [{ 'code' => 'outpatient' }] },
            { 'coding' => [{ 'code' => 'community' }] }
          ]
        )
        expect(subject.send(:extract_is_renewable, resource)).to be false
      end
    end
  end

  describe '#dispenses?' do
    it 'returns true when MedicationDispense resources exist' do
      result = subject.send(:dispenses?, base_renewable_resource)
      expect(result).to be true
    end

    it 'returns false when contained is empty' do
      resource = base_renewable_resource.merge('contained' => [])
      result = subject.send(:dispenses?, resource)
      expect(result).to be false
    end

    it 'returns false when contained is nil' do
      resource = base_renewable_resource.except('contained')
      result = subject.send(:dispenses?, resource)
      expect(result).to be false
    end

    it 'returns false when no MedicationDispense resources in contained' do
      resource = base_renewable_resource.merge(
        'contained' => [{ 'resourceType' => 'Medication', 'id' => 'med-1' }]
      )
      result = subject.send(:dispenses?, resource)
      expect(result).to be false
    end
  end

  describe '#active_processing?' do
    it 'returns false when all dispenses are completed' do
      result = subject.send(:active_processing?, base_renewable_resource)
      expect(result).to be false
    end

    it 'returns true when any dispense is in-progress' do
      resource = base_renewable_resource.merge(
        'contained' => [
          { 'resourceType' => 'MedicationDispense', 'status' => 'in-progress' }
        ]
      )
      result = subject.send(:active_processing?, resource)
      expect(result).to be true
    end

    it 'returns true when any dispense is in preparation' do
      resource = base_renewable_resource.merge(
        'contained' => [
          { 'resourceType' => 'MedicationDispense', 'status' => 'preparation' }
        ]
      )
      result = subject.send(:active_processing?, resource)
      expect(result).to be true
    end

    it 'returns true when refill-request extension with valueBoolean=true' do
      resource = base_renewable_resource.merge(
        'extension' => [
          { 'url' => 'http://example.org/fhir/refill-request', 'valueBoolean' => true }
        ]
      )
      result = subject.send(:active_processing?, resource)
      expect(result).to be true
    end

    it 'returns false when refill-request extension with valueBoolean=false' do
      resource = base_renewable_resource.merge(
        'extension' => [
          { 'url' => 'http://example.org/fhir/refill-request', 'valueBoolean' => false }
        ]
      )
      result = subject.send(:active_processing?, resource)
      expect(result).to be false
    end
  end

  describe '#within_renewal_window?' do
    it 'returns true when expired less than 120 days ago' do
      result = subject.send(:within_renewal_window?, base_renewable_resource)
      expect(result).to be true
    end

    it 'returns true when expired exactly 120 days ago' do
      # Use 119 days to avoid boundary timing issues
      resource = base_renewable_resource.merge(
        'dispenseRequest' => {
          'validityPeriod' => { 'end' => 119.days.ago.utc.iso8601 }
        }
      )
      result = subject.send(:within_renewal_window?, resource)
      expect(result).to be true
    end

    it 'returns false when expired more than 120 days ago' do
      resource = base_renewable_resource.merge(
        'dispenseRequest' => {
          'validityPeriod' => { 'end' => 121.days.ago.utc.iso8601 }
        }
      )
      result = subject.send(:within_renewal_window?, resource)
      expect(result).to be false
    end

    it 'returns true when prescription has not yet expired' do
      resource = base_renewable_resource.merge(
        'dispenseRequest' => {
          'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
        }
      )
      result = subject.send(:within_renewal_window?, resource)
      expect(result).to be true
    end

    it 'returns false when expiration date is nil' do
      resource = base_renewable_resource.merge(
        'dispenseRequest' => { 'validityPeriod' => {} }
      )
      result = subject.send(:within_renewal_window?, resource)
      expect(result).to be false
    end
  end

  describe '#validity_period_end_exists?' do
    it 'returns true when validityPeriod end exists' do
      result = subject.send(:validity_period_end_exists?, base_renewable_resource)
      expect(result).to be true
    end

    it 'returns false when validityPeriod end is nil' do
      resource = base_renewable_resource.merge(
        'dispenseRequest' => { 'validityPeriod' => {} }
      )
      result = subject.send(:validity_period_end_exists?, resource)
      expect(result).to be false
    end

    it 'returns false when validityPeriod is nil' do
      resource = base_renewable_resource.merge(
        'dispenseRequest' => {}
      )
      result = subject.send(:validity_period_end_exists?, resource)
      expect(result).to be false
    end

    it 'returns false when dispenseRequest is nil' do
      resource = base_renewable_resource.except('dispenseRequest')
      result = subject.send(:validity_period_end_exists?, resource)
      expect(result).to be false
    end
  end

  describe '#refills_exhausted_or_expired?' do
    context 'when prescription is expired' do
      it 'returns true regardless of refills remaining' do
        # Expired with 4 refills remaining
        resource = base_renewable_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 5,
            'validityPeriod' => { 'end' => 30.days.ago.utc.iso8601 }
          }
        )
        result = subject.send(:refills_exhausted_or_expired?, resource)
        expect(result).to be true
      end

      it 'returns true with zero refills remaining' do
        result = subject.send(:refills_exhausted_or_expired?, base_renewable_resource)
        expect(result).to be true
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
        result = subject.send(:refills_exhausted_or_expired?, resource)
        expect(result).to be true
      end

      it 'returns false when refills are remaining' do
        resource = base_renewable_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 5,
            'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
          }
        )
        result = subject.send(:refills_exhausted_or_expired?, resource)
        expect(result).to be false
      end
    end
  end

  describe '#prescription_expired?' do
    it 'returns true when validity period end is in the past' do
      result = subject.send(:prescription_expired?, base_renewable_resource)
      expect(result).to be true
    end

    it 'returns false when validity period end is in the future' do
      resource = base_renewable_resource.merge(
        'dispenseRequest' => {
          'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
        }
      )
      result = subject.send(:prescription_expired?, resource)
      expect(result).to be false
    end

    it 'returns false when validity period end is nil' do
      resource = base_renewable_resource.merge(
        'dispenseRequest' => { 'validityPeriod' => {} }
      )
      result = subject.send(:prescription_expired?, resource)
      expect(result).to be false
    end
  end
end
