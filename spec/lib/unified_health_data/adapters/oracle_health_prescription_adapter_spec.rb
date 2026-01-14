# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/models/prescription'
require 'unified_health_data/adapters/oracle_health_prescription_adapter'
require 'lighthouse/facilities/v1/client'

describe UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter do
  include ActiveSupport::Testing::TimeHelpers

  subject { described_class.new }

  let(:base_resource) do
    {
      'resourceType' => 'MedicationRequest',
      'id' => '12345',
      'status' => 'active',
      'authoredOn' => '2025-01-29T19:41:43Z',
      'medicationCodeableConcept' => {
        'text' => 'Test Medication'
      },
      'dosageInstruction' => [
        {
          'text' => 'Take as directed'
        }
      ]
    }
  end

  before do
    allow(Rails.cache).to receive(:exist?).and_return(false)
  end

  describe '#parse' do
    context 'with valid resource' do
      it 'returns a UnifiedHealthData::Prescription object' do
        result = subject.parse(base_resource)

        expect(result).to be_a(UnifiedHealthData::Prescription)
        expect(result.id).to eq('12345')
      end

      it 'sets cmop_division_phone to nil for Oracle Health prescriptions' do
        result = subject.parse(base_resource)

        expect(result.cmop_division_phone).to be_nil
      end

      it 'sets dial_cmop_division_phone to nil' do
        result = subject.parse(base_resource)

        expect(result.dial_cmop_division_phone).to be_nil
      end
    end

    context 'with documented/non-VA medication' do
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

      it 'returns prescription source NV' do
        result = subject.parse(non_va_resource)
        expect(result.prescription_source).to eq('NV')
      end
    end

    context 'with VA prescription' do
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

      it 'returns prescription source VA' do
        result = subject.parse(va_prescription_resource)
        expect(result.prescription_source).to eq('VA')
      end
    end

    context 'with nil resource' do
      it 'returns nil' do
        expect(subject.parse(nil)).to be_nil
      end
    end

    context 'with resource missing id' do
      let(:resource_without_id) { base_resource.except('id') }

      it 'returns nil' do
        expect(subject.parse(resource_without_id)).to be_nil
      end
    end

    context 'when parsing raises an error' do
      let(:adapter_with_error) do
        adapter = described_class.new
        allow(adapter).to receive(:extract_refill_date).and_raise(StandardError, 'Test error')
        adapter
      end

      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and returns nil' do
        result = adapter_with_error.parse(base_resource)

        expect(result).to be_nil
        expect(Rails.logger).to have_received(:error).with('Error parsing Oracle Health prescription: Test error')
      end
    end

    context 'with disclaimer field' do
      it 'sets disclaimer to nil for Oracle Health prescriptions' do
        result = subject.parse(base_resource)

        expect(result.disclaimer).to be_nil
      end
    end

    context 'with cmop_ndc_number field' do
      it 'sets cmop_ndc_number to nil for Oracle Health prescriptions' do
        result = subject.parse(base_resource)

        expect(result).to be_a(UnifiedHealthData::Prescription)
        expect(result.cmop_ndc_number).to be_nil
      end
    end

    context 'with prescription_number field' do
      it 'sets prescription_number to nil when no prescription identifier exists' do
        result = subject.parse(base_resource)

        expect(result).to be_a(UnifiedHealthData::Prescription)
        expect(result.prescription_number).to be_nil
      end

      it 'returns prescription_number when identifier with system containing "prescription" exists' do
        resource_with_prescription_id = base_resource.merge(
          'identifier' => [
            {
              'system' => 'http://example.com/prescription',
              'value' => 'RX123456'
            }
          ]
        )
        result = subject.parse(resource_with_prescription_id)

        expect(result.prescription_number).to eq('RX123456')
      end
    end

    context 'with tracking information' do
      it 'sets prescription_number to nil in tracking when dispense has no prescription number identifier' do
        resource_with_tracking_no_rx_number = base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => '21142623',
              'identifier' => [
                {
                  'type' => { 'text' => 'Tracking Number' },
                  'value' => '77298027203980000000398'
                },
                {
                  'type' => { 'text' => 'Carrier' },
                  'value' => 'UPS'
                }
              ]
            }
          ]
        )

        result = subject.send(:build_tracking_information, resource_with_tracking_no_rx_number)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)

        tracking = result.first
        expect(tracking[:prescription_number]).to be_nil
        expect(tracking[:tracking_number]).to eq('77298027203980000000398')
      end
    end

    context 'with inpatient medication (should be filtered)' do
      let(:inpatient_resource) do
        base_resource.merge(
          'category' => [
            { 'coding' => [{ 'code' => 'inpatient' }] }
          ]
        )
      end

      it 'returns nil (filtered out)' do
        expect(subject.parse(inpatient_resource)).to be_nil
      end
    end

    context 'with pharmacy charges medication (should be filtered)' do
      let(:charge_only_resource) do
        base_resource.merge(
          'category' => [
            { 'coding' => [{ 'code' => 'charge-only' }] }
          ]
        )
      end

      it 'returns nil (filtered out)' do
        expect(subject.parse(charge_only_resource)).to be_nil
      end
    end

    context 'with uncategorized medication' do
      let(:uncategorized_resource) do
        base_resource.merge(
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'unknown-category' }] }
          ]
        )
      end

      before { allow(Rails.logger).to receive(:warn) }

      it 'returns the prescription (visible but logged)' do
        result = subject.parse(uncategorized_resource)
        expect(result).to be_a(UnifiedHealthData::Prescription)
      end

      context 'when mhv_medications_v2_status_mapping is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_medications_v2_status_mapping).and_return(true)
        end

        it 'logs the uncategorized medication for review' do
          subject.parse(uncategorized_resource)
          expect(Rails.logger).to have_received(:warn).with(
            hash_including(
              message: 'Oracle Health medication uncategorized',
              service: 'unified_health_data'
            )
          )
        end
      end

      context 'when mhv_medications_v2_status_mapping is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_medications_v2_status_mapping).and_return(false)
        end

        it 'does not log the uncategorized medication' do
          subject.parse(uncategorized_resource)
          expect(Rails.logger).not_to have_received(:warn)
        end
      end
    end
  end

  describe '#extract_prescription_source' do
    context 'with VA prescription' do
      let(:va_resource) do
        base_resource.merge(
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'discharge' }] }
          ]
        )
      end

      it 'returns VA for VA prescriptions' do
        result = subject.send(:extract_prescription_source, va_resource)
        expect(result).to eq('VA')
      end
    end

    context 'with documented/non-VA medication' do
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

      it 'returns NV for documented/non-VA medications' do
        result = subject.send(:extract_prescription_source, non_va_resource)
        expect(result).to eq('NV')
      end
    end

    context 'with uncategorized medication' do
      it 'returns NV for uncategorized medications' do
        result = subject.send(:extract_prescription_source, base_resource)
        expect(result).to eq('NV')
      end
    end
  end

  # NOTE: #extract_facility_name and facility lookup tests moved to facility_name_resolver_spec.rb
  # The adapter now delegates facility name extraction to FacilityNameResolver

  describe '#extract_is_refillable' do
    let(:base_refillable_resource) do
      {
        'status' => 'active',
        'reportedBoolean' => false,
        'intent' => 'order',
        'category' => [
          { 'coding' => [{ 'code' => 'community' }] },
          { 'coding' => [{ 'code' => 'discharge' }] }
        ],
        'dispenseRequest' => {
          'numberOfRepeatsAllowed' => 5,
          'validityPeriod' => {
            'end' => 1.minute.from_now.in_time_zone('Pacific/Honolulu').iso8601
          }
        },
        'contained' => [
          {
            'resourceType' => 'MedicationDispense',
            'id' => 'dispense-1',
            'status' => 'completed',
            'whenHandedOver' => '2025-01-15T10:00:00Z'
          }
        ]
      }
    end

    context 'with all conditions met for refillable prescription' do
      it 'returns true' do
        expect(subject.send(:extract_is_refillable, base_refillable_resource, 'active')).to be true
      end
    end

    context 'with non-VA medication (documented/non-VA)' do
      let(:non_va_resource) do
        base_refillable_resource.merge(
          'reportedBoolean' => true,
          'intent' => 'plan',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'patientspecified' }] }
          ]
        )
      end

      it 'returns false for non-VA medications' do
        expect(subject.send(:extract_is_refillable, non_va_resource, 'active')).to be false
      end
    end

    context 'with inactive status' do
      let(:inactive_resource) do
        base_refillable_resource.merge('status' => 'completed')
      end

      it 'returns false when status is not active' do
        expect(subject.send(:extract_is_refillable, inactive_resource, 'active')).to be false
      end
    end

    context 'with null status' do
      let(:null_status_resource) do
        base_refillable_resource.merge('status' => nil)
      end

      it 'returns false when status is null' do
        expect(subject.send(:extract_is_refillable, null_status_resource, 'active')).to be false
      end
    end

    context 'with expired prescription' do
      let(:expired_resource) do
        expired_date = 1.minute.ago.in_time_zone('America/Los_Angeles').iso8601
        base_refillable_resource.deep_merge(
          'dispenseRequest' => {
            'validityPeriod' => {
              'end' => expired_date
            }
          }
        )
      end

      it 'returns false when prescription is expired' do
        expect(subject.send(:extract_is_refillable, expired_resource, 'active')).to be false
      end
    end

    context 'with no expiration date' do
      let(:no_expiration_resource) do
        resource = base_refillable_resource.dup
        resource['dispenseRequest'].delete('validityPeriod')
        resource
      end

      it 'returns false when no expiration date (safety default)' do
        expect(subject.send(:extract_is_refillable, no_expiration_resource, 'active')).to be false
      end
    end

    context 'with invalid expiration date' do
      let(:invalid_expiration_resource) do
        base_refillable_resource.deep_merge(
          'dispenseRequest' => {
            'validityPeriod' => {
              'end' => 'invalid-date'
            }
          }
        )
      end

      before do
        allow(Rails.logger).to receive(:warn)
      end

      it 'returns false and logs warning for invalid dates' do
        expect(subject.send(:extract_is_refillable, invalid_expiration_resource, 'active')).to be false
        expect(Rails.logger).to have_received(:warn).with(
          /Failed to parse expiration date 'invalid-date'/
        )
      end
    end

    context 'with no refills remaining' do
      let(:no_refills_resource) do
        base_refillable_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 0,
            'validityPeriod' => {
              'end' => 1.year.from_now.iso8601
            }
          }
        )
      end

      it 'returns false when no refills remaining' do
        expect(subject.send(:extract_is_refillable, no_refills_resource, 'active')).to be false
      end
    end

    context 'with multiple failing conditions' do
      let(:multiple_fail_resource) do
        {
          'status' => 'completed',
          'reportedBoolean' => true,
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 0,
            'validityPeriod' => {
              'end' => 1.day.ago.iso8601
            }
          }
        }
      end

      it 'returns false when multiple conditions fail' do
        expect(subject.send(:extract_is_refillable, multiple_fail_resource, 'active')).to be false
      end
    end

    context 'with exactly one refill remaining' do
      let(:one_refill_resource) do
        base_refillable_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 2,
            'validityPeriod' => {
              'end' => 1.year.from_now.iso8601
            }
          },
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'status' => 'completed'
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-2',
              'status' => 'completed'
            }
          ]
        )
      end

      it 'returns true when exactly one refill remains' do
        expect(subject.send(:extract_is_refillable, one_refill_resource, 'active')).to be true
      end
    end

    context 'with in-progress dispense' do
      let(:in_progress_dispense_resource) do
        base_refillable_resource.merge(
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
              'status' => 'in-progress',
              'whenHandedOver' => '2025-01-20T10:00:00Z'
            }
          ]
        )
      end

      it 'returns false when most recent dispense is in-progress' do
        expect(subject.send(:extract_is_refillable, in_progress_dispense_resource, 'active')).to be false
      end
    end

    context 'with preparation status dispense' do
      let(:preparation_dispense_resource) do
        base_refillable_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'status' => 'preparation',
              'whenHandedOver' => '2025-01-15T10:00:00Z'
            }
          ]
        )
      end

      it 'returns false when most recent dispense is preparation' do
        expect(subject.send(:extract_is_refillable, preparation_dispense_resource, 'active')).to be false
      end
    end

    context 'with on-hold status dispense' do
      let(:on_hold_dispense_resource) do
        base_refillable_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'status' => 'on-hold',
              'whenHandedOver' => '2025-01-15T10:00:00Z'
            }
          ]
        )
      end

      it 'returns false when most recent dispense is on-hold' do
        expect(subject.send(:extract_is_refillable, on_hold_dispense_resource, 'active')).to be false
      end
    end

    context 'with submitted refill status' do
      it 'returns false when refill_status is submitted' do
        expect(subject.send(:extract_is_refillable, base_refillable_resource, 'submitted')).to be false
      end
    end
  end

  describe '#extract_is_renewable' do
    # Base renewable resource: active status, VA Prescription classification
    # (reportedBoolean=false, intent='order', community + discharge categories),
    # has dispense, zero refills remaining, no active processing, within 120 days
    let(:base_renewable_resource) do
      {
        'status' => 'active',
        'reportedBoolean' => false,
        'intent' => 'order',
        'category' => [
          {
            'coding' => [
              { 'code' => 'community' }
            ]
          },
          {
            'coding' => [
              { 'code' => 'discharge' }
            ]
          }
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

    context 'with all conditions met for renewable VA prescription' do
      it 'returns true' do
        expect(subject.send(:extract_is_renewable, base_renewable_resource)).to be true
      end
    end

    # Gate 1: Status must be active
    context 'Gate 1: with non-active status' do
      let(:inactive_resource) do
        base_renewable_resource.merge('status' => 'completed')
      end

      it 'returns false when status is not active' do
        expect(subject.send(:extract_is_renewable, inactive_resource)).to be false
      end
    end

    # Gate 2: Must be classified as VA Prescription or Clinic Administered Medication
    context 'Gate 2: with Documented/Non-VA medication classification' do
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

    context 'Gate 2: with unclassified medication (wrong intent)' do
      let(:wrong_intent_resource) do
        base_renewable_resource.merge('intent' => 'plan')
      end

      it 'returns false when intent is not order' do
        expect(subject.send(:extract_is_renewable, wrong_intent_resource)).to be false
      end
    end

    context 'Gate 2: with unclassified medication (missing discharge category for VA Prescription)' do
      let(:missing_discharge_resource) do
        base_renewable_resource.merge(
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] }
          ]
        )
      end

      it 'returns false when community category without discharge' do
        expect(subject.send(:extract_is_renewable, missing_discharge_resource)).to be false
      end
    end

    context 'Gate 2: with Clinic Administered medication (outpatient category)' do
      let(:clinic_administered_resource) do
        base_renewable_resource.merge(
          'category' => [
            { 'coding' => [{ 'code' => 'outpatient' }] }
          ]
        )
      end

      it 'returns false for Clinic Administered medications' do
        expect(subject.send(:extract_is_renewable, clinic_administered_resource)).to be false
      end
    end

    context 'Gate 2: with inpatient category (unclassified)' do
      let(:inpatient_resource) do
        base_renewable_resource.merge(
          'category' => [
            {
              'coding' => [
                { 'code' => 'inpatient' }
              ]
            }
          ]
        )
      end

      it 'returns false for inpatient category' do
        expect(subject.send(:extract_is_renewable, inpatient_resource)).to be false
      end
    end

    context 'Gate 2: with no category (unclassified)' do
      let(:no_category_resource) do
        base_renewable_resource.merge('category' => [])
      end

      it 'returns false when category is empty' do
        expect(subject.send(:extract_is_renewable, no_category_resource)).to be false
      end
    end

    context 'Gate 2: with reportedBoolean true but correct VA Prescription categories' do
      let(:reported_with_va_categories) do
        base_renewable_resource.merge('reportedBoolean' => true)
      end

      it 'returns false because reportedBoolean must be false for VA Prescription' do
        expect(subject.send(:extract_is_renewable, reported_with_va_categories)).to be false
      end
    end

    # Gate 3: Must have at least one dispense
    context 'Gate 3: with no dispenses' do
      let(:no_dispense_resource) do
        base_renewable_resource.merge('contained' => [])
      end

      it 'returns false when no dispenses exist' do
        expect(subject.send(:extract_is_renewable, no_dispense_resource)).to be false
      end
    end

    context 'Gate 3: with nil contained resources' do
      let(:nil_contained_resource) do
        base_renewable_resource.except('contained')
      end

      it 'returns false when contained is nil' do
        expect(subject.send(:extract_is_renewable, nil_contained_resource)).to be false
      end
    end

    # Gate 6: Refills exhausted OR prescription expired
    # Note: If prescription is expired (validity period ended), it IS renewable even with refills remaining
    context 'Gate 6: with refills remaining but prescription expired' do
      let(:refills_remaining_resource) do
        base_renewable_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 5,
            'validityPeriod' => {
              'end' => 30.days.ago.utc.iso8601
            }
          }
        )
      end

      it 'returns true when refills remain but prescription is expired' do
        expect(subject.send(:extract_is_renewable, refills_remaining_resource)).to be true
      end
    end

    # Gate 7: No active processing
    context 'Gate 7: with in-progress dispense' do
      let(:in_progress_resource) do
        base_renewable_resource.merge(
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
              'status' => 'in-progress',
              'whenHandedOver' => '2025-01-20T10:00:00Z'
            }
          ]
        )
      end

      it 'returns false when a dispense is in-progress' do
        expect(subject.send(:extract_is_renewable, in_progress_resource)).to be false
      end
    end

    context 'Gate 7: with preparation dispense' do
      let(:preparation_resource) do
        base_renewable_resource.merge(
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
              'status' => 'preparation',
              'whenHandedOver' => '2025-01-20T10:00:00Z'
            }
          ]
        )
      end

      it 'returns false when a dispense is in preparation' do
        expect(subject.send(:extract_is_renewable, preparation_resource)).to be false
      end
    end

    context 'Gate 7: with web/mobile refill request extension' do
      let(:refill_requested_resource) do
        base_renewable_resource.merge(
          'extension' => [
            {
              'url' => 'http://example.org/fhir/refill-request',
              'valueBoolean' => true
            }
          ]
        )
      end

      it 'returns false when refill requested via web/mobile' do
        expect(subject.send(:extract_is_renewable, refill_requested_resource)).to be false
      end
    end

    # Gate 5: Within 120 days of validity period end
    context 'Gate 5: expired more than 120 days ago' do
      let(:old_expired_resource) do
        base_renewable_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 1,
            'validityPeriod' => {
              'end' => 150.days.ago.utc.iso8601
            }
          }
        )
      end

      it 'returns false when expired more than 120 days ago' do
        expect(subject.send(:extract_is_renewable, old_expired_resource)).to be false
      end
    end

    context 'Gate 6: expired exactly 120 days ago' do
      it 'returns true when expired within 120 days (boundary case)' do
        travel_to Time.zone.parse('2026-01-08 12:00:00 UTC') do
          # Expiration was exactly 120 days ago at the same time of day
          # 2026-01-08 12:00 - 120 days = 2025-09-10 12:00
          expiration_date = Time.zone.parse('2025-09-10 12:00:00 UTC').iso8601
          resource = base_renewable_resource.merge(
            'dispenseRequest' => {
              'numberOfRepeatsAllowed' => 1,
              'validityPeriod' => { 'end' => expiration_date }
            }
          )
          expect(subject.send(:extract_is_renewable, resource)).to be true
        end
      end
    end

    context 'Gate 6: not yet expired' do
      let(:not_expired_resource) do
        base_renewable_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 1,
            'validityPeriod' => {
              'end' => 30.days.from_now.utc.iso8601
            }
          }
        )
      end

      it 'returns true when not yet expired' do
        expect(subject.send(:extract_is_renewable, not_expired_resource)).to be true
      end
    end

    context 'Gate 6: with no validity period' do
      let(:no_validity_resource) do
        resource = base_renewable_resource.dup
        resource['dispenseRequest'] = { 'numberOfRepeatsAllowed' => 1 }
        resource
      end

      it 'returns false when no validity period exists' do
        expect(subject.send(:extract_is_renewable, no_validity_resource)).to be false
      end
    end
  end

  describe '#extract_station_number' do
    let(:resource_with_station_number) do
      {
        'contained' => [
          {
            'resourceType' => 'MedicationDispense',
            'id' => 'dispense-1',
            'location' => { 'display' => '556-RX-MAIN-OP' }
          }
        ]
      }
    end

    context 'with valid 3-digit station number format' do
      it 'extracts the first 3 digits' do
        result = subject.send(:extract_station_number, resource_with_station_number)
        expect(result).to eq('556')
      end
    end

    context 'with format that has less than 3 leading digits' do
      let(:resource_with_short_digits) do
        {
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'location' => { 'display' => '12-PHARMACY' }
            }
          ]
        }
      end

      before do
        allow(Rails.logger).to receive(:warn)
      end

      it 'falls back to original value and logs warning' do
        result = subject.send(:extract_station_number, resource_with_short_digits)
        expect(result).to eq('12-PHARMACY')
        expect(Rails.logger).to have_received(:warn).with(
          'Unable to extract 3-digit station number from: 12-PHARMACY'
        )
      end
    end

    context 'with no MedicationDispense in contained resources' do
      let(:resource_without_dispense) do
        {
          'contained' => [
            {
              'resourceType' => 'Encounter',
              'id' => 'encounter-1'
            }
          ]
        }
      end

      it 'returns nil' do
        result = subject.send(:extract_station_number, resource_without_dispense)
        expect(result).to be_nil
      end
    end
  end

  describe '#build_tracking_information' do
    context 'with MedicationDispense containing tracking identifiers' do
      let(:resource_with_tracking) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => '21142623',
              'identifier' => [
                {
                  'type' => { 'text' => 'Tracking Number' },
                  'value' => '77298027203980000000398'
                },
                {
                  'type' => { 'text' => 'Prescription Number' },
                  'value' => '2720334'
                },
                {
                  'type' => { 'text' => 'Carrier' },
                  'value' => 'UPS'
                },
                {
                  'type' => { 'text' => 'Shipped Date' },
                  'value' => '2022-10-15T00:00:00.000Z'
                }
              ],
              'medicationCodeableConcept' => {
                'coding' => [
                  {
                    'system' => 'http://hl7.org/fhir/sid/ndc',
                    'code' => '00013264681'
                  }
                ]
              }
            }
          ],
          'medicationCodeableConcept' => {
            'text' => 'HALCINONIDE 0.1% OINT'
          }
        )
      end

      it 'returns tracking information with all fields' do
        result = subject.send(:build_tracking_information, resource_with_tracking)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)

        tracking = result.first
        expect(tracking).to include(
          prescription_name: 'HALCINONIDE 0.1% OINT',
          prescription_number: '2720334',
          ndc_number: '00013264681',
          prescription_id: '12345',
          tracking_number: '77298027203980000000398',
          shipped_date: '2022-10-15T00:00:00.000Z',
          carrier: 'UPS',
          other_prescriptions: []
        )
      end

      it 'sets is_trackable to true when tracking data exists' do
        result = subject.parse(resource_with_tracking)
        expect(result.is_trackable).to be(true)
      end
    end

    context 'with MedicationDispense without tracking identifiers' do
      let(:resource_no_tracking) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => '123456',
              'identifier' => [
                {
                  'type' => { 'text' => 'Other ID' },
                  'value' => 'some-other-value'
                }
              ]
            }
          ]
        )
      end

      it 'returns empty array when no tracking number is found' do
        result = subject.send(:build_tracking_information, resource_no_tracking)
        expect(result).to eq([])
      end

      it 'sets is_trackable to false when no tracking data exists' do
        result = subject.parse(resource_no_tracking)
        expect(result.is_trackable).to be(false)
      end
    end

    context 'with multiple MedicationDispense resources' do
      let(:resource_multiple_dispenses) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => '111',
              'identifier' => [
                {
                  'type' => { 'text' => 'Tracking Number' },
                  'value' => 'TRACK111'
                },
                {
                  'type' => { 'text' => 'Carrier' },
                  'value' => 'USPS'
                }
              ]
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => '222',
              'identifier' => [
                {
                  'type' => { 'text' => 'Tracking Number' },
                  'value' => 'TRACK222'
                },
                {
                  'type' => { 'text' => 'Carrier' },
                  'value' => 'FedEx'
                }
              ]
            }
          ]
        )
      end

      it 'returns tracking information for all dispenses with tracking numbers' do
        result = subject.send(:build_tracking_information, resource_multiple_dispenses)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)

        expect(result.map { |t| t[:tracking_number] }).to contain_exactly('TRACK111', 'TRACK222')
        expect(result.map { |t| t[:carrier] }).to contain_exactly('USPS', 'FedEx')
      end
    end

    context 'with no contained resources' do
      it 'returns empty array' do
        result = subject.send(:build_tracking_information, base_resource)
        expect(result).to eq([])
      end

      it 'sets is_trackable to false' do
        result = subject.parse(base_resource)
        expect(result.is_trackable).to be(false)
      end
    end
  end

  describe '#extract_ndc_number' do
    context 'with NDC coding in medicationCodeableConcept' do
      let(:dispense_with_ndc) do
        {
          'resourceType' => 'MedicationDispense',
          'id' => 'dispense-1',
          'medicationCodeableConcept' => {
            'coding' => [
              {
                'system' => 'http://hl7.org/fhir/sid/ndc',
                'code' => '12345-678-90'
              },
              {
                'system' => 'http://other.system',
                'code' => 'OTHER123'
              }
            ]
          }
        }
      end

      it 'returns the NDC code' do
        result = subject.send(:extract_ndc_number, dispense_with_ndc)
        expect(result).to eq('12345-678-90')
      end
    end

    context 'without NDC coding' do
      let(:dispense_without_ndc) do
        {
          'resourceType' => 'MedicationDispense',
          'id' => 'dispense-1'
        }
      end

      it 'returns nil' do
        result = subject.send(:extract_ndc_number, dispense_without_ndc)
        expect(result).to be_nil
      end
    end
  end

  describe '#build_dispenses_information' do
    context 'with MedicationDispense resources in contained' do
      let(:resource_with_dispenses) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-1',
              'status' => 'completed',
              'whenHandedOver' => '2025-01-15T10:00:00Z',
              'quantity' => { 'value' => 30 },
              'location' => { 'display' => '648-PHARMACY-MAIN' },
              'dosageInstruction' => [
                {
                  'text' => 'Take one tablet by mouth daily'
                }
              ],
              'medicationCodeableConcept' => {
                'text' => 'amLODIPine 5 mg tablet'
              }
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-2',
              'status' => 'completed',
              'whenHandedOver' => '2025-01-29T14:30:00Z',
              'quantity' => { 'value' => 30 },
              'location' => { 'display' => '648-PHARMACY-MAIN' },
              'dosageInstruction' => [
                {
                  'text' => 'Take one tablet by mouth daily'
                }
              ],
              'medicationCodeableConcept' => {
                'text' => 'amLODIPine 5 mg tablet'
              }
            }
          ]
        )
      end

      before do
        allow(Rails.cache).to receive(:read).with('uhd:facility_names:648').and_return('Portland VA Medical Center')
        allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:648').and_return(true)
      end

      it 'returns dispenses information with all fields' do
        result = subject.send(:build_dispenses_information, resource_with_dispenses)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)

        first_dispense = result.first
        expect(first_dispense).to include(
          status: 'completed',
          refill_date: '2025-01-15T10:00:00Z',
          facility_name: 'Portland VA Medical Center',
          instructions: 'Take one tablet by mouth daily',
          quantity: 30,
          medication_name: 'amLODIPine 5 mg tablet',
          id: 'dispense-1'
        )
        # Verify new Vista-only fields are nil for Oracle Health
        expect(first_dispense[:refill_submit_date]).to be_nil
        expect(first_dispense[:prescription_number]).to be_nil
        expect(first_dispense[:cmop_division_phone]).to be_nil
        expect(first_dispense[:cmop_ndc_number]).to be_nil
        expect(first_dispense[:remarks]).to be_nil
        expect(first_dispense[:dial_cmop_division_phone]).to be_nil
        expect(first_dispense[:disclaimer]).to be_nil

        second_dispense = result.second
        expect(second_dispense).to include(
          status: 'completed',
          refill_date: '2025-01-29T14:30:00Z',
          facility_name: 'Portland VA Medical Center',
          instructions: 'Take one tablet by mouth daily',
          quantity: 30,
          medication_name: 'amLODIPine 5 mg tablet',
          id: 'dispense-2'
        )
        # Verify new Vista-only fields are nil for Oracle Health
        expect(second_dispense[:refill_submit_date]).to be_nil
        expect(second_dispense[:prescription_number]).to be_nil
        expect(second_dispense[:cmop_division_phone]).to be_nil
        expect(second_dispense[:cmop_ndc_number]).to be_nil
        expect(second_dispense[:remarks]).to be_nil
        expect(second_dispense[:dial_cmop_division_phone]).to be_nil
        expect(second_dispense[:disclaimer]).to be_nil
      end

      it 'includes dispenses in parsed prescription' do
        result = subject.parse(resource_with_dispenses)
        expect(result.dispenses.length).to eq(2)
        expect(result.dispenses.first[:status]).to eq('completed')
      end
    end

    context 'with no MedicationDispense resources' do
      it 'returns empty array when no contained resources' do
        result = subject.send(:build_dispenses_information, base_resource)
        expect(result).to eq([])
      end

      it 'returns empty array when contained has no MedicationDispense' do
        resource_no_dispenses = base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'Encounter',
              'id' => 'encounter-1'
            }
          ]
        )
        result = subject.send(:build_dispenses_information, resource_no_dispenses)
        expect(result).to eq([])
      end

      it 'includes empty dispenses array in parsed prescription' do
        result = subject.parse(base_resource)
        expect(result.dispenses).to eq([])
      end
    end

    context 'with MedicationDispense missing optional fields' do
      let(:resource_with_minimal_dispense) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'dispense-minimal',
              'status' => 'completed'
            }
          ]
        )
      end

      it 'returns dispense with nil values for missing fields' do
        result = subject.send(:build_dispenses_information, resource_with_minimal_dispense)

        expect(result).to be_an(Array)
        expect(result.length).to eq(1)

        dispense = result.first
        expect(dispense[:status]).to eq('completed')
        expect(dispense[:refill_date]).to be_nil
        expect(dispense[:facility_name]).to be_nil
        expect(dispense[:sig]).to be_nil
        expect(dispense[:quantity]).to be_nil
        expect(dispense[:medication_name]).to be_nil
        expect(dispense[:id]).to eq('dispense-minimal')
      end
    end

    context 'with non-hash elements in contained resources' do
      let(:resource_with_invalid_elements) do
        base_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'valid-1',
              'status' => 'completed',
              'whenHandedOver' => '2025-01-15T10:00:00Z'
            },
            'invalid-string-element',
            nil,
            123,
            {
              'resourceType' => 'Encounter',
              'id' => 'encounter-1'
            },
            {
              'resourceType' => 'MedicationDispense',
              'id' => 'valid-2',
              'status' => 'completed',
              'whenHandedOver' => '2025-01-20T10:00:00Z'
            }
          ]
        )
      end

      it 'filters out non-hash elements and non-MedicationDispense resources' do
        result = subject.send(:build_dispenses_information, resource_with_invalid_elements)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first[:id]).to eq('valid-1')
        expect(result.second[:id]).to eq('valid-2')
      end
    end
  end

  describe '#extract_sig_from_dispense' do
    context 'with dosageInstruction text' do
      let(:dispense_with_sig) do
        {
          'dosageInstruction' => [
            {
              'text' => 'Take one tablet by mouth daily'
            }
          ]
        }
      end

      it 'returns the dosage instruction text' do
        result = subject.send(:extract_sig_from_dispense, dispense_with_sig)
        expect(result).to eq('Take one tablet by mouth daily')
      end
    end

    context 'without dosageInstruction' do
      let(:dispense_without_sig) do
        {}
      end

      it 'returns nil' do
        result = subject.send(:extract_sig_from_dispense, dispense_without_sig)
        expect(result).to be_nil
      end
    end

    context 'with empty dosageInstruction array' do
      let(:dispense_empty_sig) do
        {
          'dosageInstruction' => []
        }
      end

      it 'returns nil' do
        result = subject.send(:extract_sig_from_dispense, dispense_empty_sig)
        expect(result).to be_nil
      end
    end

    context 'with non-hash element as first dosageInstruction' do
      let(:dispense_invalid_instruction) do
        {
          'dosageInstruction' => ['invalid-string-element']
        }
      end

      it 'returns nil when first instruction is not a hash' do
        result = subject.send(:extract_sig_from_dispense, dispense_invalid_instruction)
        expect(result).to be_nil
      end
    end

    context 'with multiple dosageInstruction elements' do
      let(:dispense_multiple_instructions) do
        {
          'dosageInstruction' => [
            {
              'text' => 'Take one tablet by mouth daily'
            },
            {
              'text' => 'with food'
            },
            {
              'text' => 'in the morning'
            }
          ]
        }
      end

      it 'concatenates all dosage instruction texts' do
        result = subject.send(:extract_sig_from_dispense, dispense_multiple_instructions)
        expect(result).to eq('Take one tablet by mouth daily with food in the morning')
      end
    end

    context 'with multiple dosageInstruction elements including non-hash' do
      let(:dispense_mixed_instructions) do
        {
          'dosageInstruction' => [
            {
              'text' => 'Take one tablet'
            },
            'invalid-string-element',
            {
              'text' => 'with food'
            },
            nil
          ]
        }
      end

      it 'concatenates only valid hash elements with text' do
        result = subject.send(:extract_sig_from_dispense, dispense_mixed_instructions)
        expect(result).to eq('Take one tablet with food')
      end
    end
  end

  describe '#extract_facility_name_from_dispense' do
    let(:dispense_with_location) do
      {
        'resourceType' => 'MedicationDispense',
        'id' => 'dispense-1',
        'location' => { 'display' => '556-RX-MAIN-OP' }
      }
    end

    let(:resource_for_facility) { base_resource }

    before do
      allow(Rails.cache).to receive(:read).with('uhd:facility_names:556').and_return('Bay Pines VA Healthcare System')
      allow(Rails.cache).to receive(:exist?).with('uhd:facility_names:556').and_return(true)
    end
  end

  describe '#extract_indication_for_use' do
    context 'with reasonCode field containing text' do
      let(:resource_with_reason_code) do
        base_resource.merge(
          'reasonCode' => [
            {
              'coding' => [
                {
                  'system' => 'http://hl7.org/fhir/sid/icd-10-cm',
                  'code' => 'K21.9',
                  'display' => 'Gastro-esophageal reflux disease without esophagitis',
                  'userSelected' => true
                }
              ],
              'text' => 'Acid reflux'
            }
          ]
        )
      end

      it 'returns the text from the first reasonCode' do
        result = subject.send(:extract_indication_for_use, resource_with_reason_code)
        expect(result).to eq('Acid reflux')
      end
    end

    context 'with multiple reasonCode entries' do
      let(:resource_with_multiple_reason_codes) do
        base_resource.merge(
          'reasonCode' => [
            {
              'coding' => [
                {
                  'system' => 'http://hl7.org/fhir/sid/icd-10-cm',
                  'code' => 'L70.0',
                  'display' => 'Acne vulgaris',
                  'userSelected' => true
                }
              ],
              'text' => 'Acne'
            },
            {
              'coding' => [
                {
                  'system' => 'http://hl7.org/fhir/sid/icd-10-cm',
                  'code' => 'Z12.11',
                  'display' => 'Encounter for screening for malignant neoplasm of colon',
                  'userSelected' => true
                }
              ],
              'text' => 'Encounter for screening fecal occult blood testing'
            }
          ]
        )
      end

      it 'concatenates text from all reasonCode entries' do
        result = subject.send(:extract_indication_for_use, resource_with_multiple_reason_codes)
        expect(result).to eq('Acne; Encounter for screening fecal occult blood testing')
      end
    end

    context 'with no reasonCode field' do
      it 'returns nil' do
        result = subject.send(:extract_indication_for_use, base_resource)
        expect(result).to be_nil
      end
    end

    context 'with empty reasonCode array' do
      let(:resource_with_empty_reason_code) do
        base_resource.merge('reasonCode' => [])
      end

      it 'returns nil' do
        result = subject.send(:extract_indication_for_use, resource_with_empty_reason_code)
        expect(result).to be_nil
      end
    end

    context 'with reasonCode but no text field' do
      let(:resource_with_reason_code_no_text) do
        base_resource.merge(
          'reasonCode' => [
            {
              'coding' => [
                {
                  'system' => 'http://hl7.org/fhir/sid/icd-10-cm',
                  'code' => 'K21.9',
                  'display' => 'Gastro-esophageal reflux disease without esophagitis',
                  'userSelected' => true
                }
              ]
            }
          ]
        )
      end

      it 'returns nil' do
        result = subject.send(:extract_indication_for_use, resource_with_reason_code_no_text)
        expect(result).to be_nil
      end
    end

    context 'with multiple reasonCode entries where some have no text' do
      let(:resource_with_mixed_reason_codes) do
        base_resource.merge(
          'reasonCode' => [
            {
              'coding' => [
                {
                  'system' => 'http://hl7.org/fhir/sid/icd-10-cm',
                  'code' => 'L70.0',
                  'display' => 'Acne vulgaris',
                  'userSelected' => true
                }
              ],
              'text' => 'Acne'
            },
            {
              'coding' => [
                {
                  'system' => 'http://hl7.org/fhir/sid/icd-10-cm',
                  'code' => 'K21.9',
                  'display' => 'Gastro-esophageal reflux disease without esophagitis',
                  'userSelected' => true
                }
              ]
            },
            {
              'coding' => [
                {
                  'system' => 'http://hl7.org/fhir/sid/icd-10-cm',
                  'code' => 'Z12.11',
                  'display' => 'Encounter for screening for malignant neoplasm of colon',
                  'userSelected' => true
                }
              ],
              'text' => 'Screening'
            }
          ]
        )
      end

      it 'concatenates only the text fields that are present' do
        result = subject.send(:extract_indication_for_use, resource_with_mixed_reason_codes)
        expect(result).to eq('Acne; Screening')
      end
    end
  end

  describe '#normalize_to_legacy_vista_status' do
    let(:status_test_resource) do
      {
        'id' => 'test-123',
        'status' => 'active',
        'reportedBoolean' => false,
        'intent' => 'order',
        'category' => [
          { 'coding' => [{ 'code' => 'community' }] },
          { 'coding' => [{ 'code' => 'discharge' }] }
        ],
        'dispenseRequest' => {
          'numberOfRepeatsAllowed' => 3,
          'validityPeriod' => { 'end' => 1.year.from_now.utc.iso8601 }
        },
        'contained' => []
      }
    end

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
    end

    context 'when MedicationRequest status is active' do
      it 'returns "discontinued" when expired more than 120 days ago' do
        travel_to Time.zone.parse('2026-01-08 12:00:00 UTC') do
          # Expiration was 121 days ago at midnight (beyond the 120-day window)
          expiration_date = Time.zone.parse('2025-09-09 00:00:00 UTC').iso8601
          resource = status_test_resource.merge(
            'dispenseRequest' => {
              'validityPeriod' => { 'end' => expiration_date }
            }
          )

          result = subject.send(:normalize_to_legacy_vista_status, resource)
          expect(result).to eq('discontinued')
        end
      end

      it 'returns "expired" when no refills remaining' do
        resource = status_test_resource.merge(
          'dispenseRequest' => { 'numberOfRepeatsAllowed' => 0 },
          'contained' => []
        )

        result = subject.send(:normalize_to_legacy_vista_status, resource)
        expect(result).to eq('expired')
      end

      it 'returns "refillinprocess" when the most recent dispense is preparation' do
        resource = status_test_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'status' => 'preparation'
            }
          ]
        )

        result = subject.send(:normalize_to_legacy_vista_status, resource)
        expect(result).to eq('refillinprocess')
      end

      it 'returns "refillinprocess" when most recent dispense is in-progress' do
        resource = status_test_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'status' => 'completed',
              'whenHandedOver' => 2.days.ago.utc.iso8601
            },
            {
              'resourceType' => 'MedicationDispense',
              'status' => 'in-progress',
              'whenHandedOver' => 1.day.ago.utc.iso8601
            }
          ]
        )

        result = subject.send(:normalize_to_legacy_vista_status, resource)
        expect(result).to eq('refillinprocess')
      end

      it 'returns "refillinprocess" when the most recent dispense is on-hold' do
        resource = status_test_resource.merge(
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'status' => 'on-hold'
            }
          ]
        )

        result = subject.send(:normalize_to_legacy_vista_status, resource)
        expect(result).to eq('refillinprocess')
      end

      it 'returns "active" when no special conditions apply' do
        result = subject.send(:normalize_to_legacy_vista_status, status_test_resource)
        expect(result).to eq('active')
      end

      it 'returns "active" when there is no validityPeriod.end date' do
        resource = status_test_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => {}
          }
        )

        result = subject.send(:normalize_to_legacy_vista_status, resource)
        expect(result).to eq('active')
      end

      it 'returns "expired" when no refills remaining even without validityPeriod.end' do
        resource = status_test_resource.merge(
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 0,
            'validityPeriod' => {}
          },
          'contained' => []
        )

        result = subject.send(:normalize_to_legacy_vista_status, resource)
        expect(result).to eq('expired')
      end
    end

    context 'when MedicationRequest status is on-hold' do
      it 'returns "providerHold"' do
        resource = status_test_resource.merge('status' => 'on-hold')

        result = subject.send(:normalize_to_legacy_vista_status, resource)
        expect(result).to eq('providerHold')
      end
    end

    context 'when MedicationRequest status is cancelled' do
      it 'returns "discontinued"' do
        resource = status_test_resource.merge('status' => 'cancelled')

        result = subject.send(:normalize_to_legacy_vista_status, resource)
        expect(result).to eq('discontinued')
      end
    end

    context 'when MedicationRequest status is completed' do
      it 'returns "discontinued" when expired more than 120 days ago' do
        travel_to Time.zone.parse('2026-01-08 12:00:00 UTC') do
          # Expiration was 121 days ago at midnight (beyond the 120-day window)
          expiration_date = Time.zone.parse('2025-09-09 00:00:00 UTC').iso8601
          resource = status_test_resource.merge(
            'status' => 'completed',
            'dispenseRequest' => {
              'validityPeriod' => { 'end' => expiration_date }
            }
          )

          result = subject.send(:normalize_to_legacy_vista_status, resource)
          expect(result).to eq('discontinued')
        end
      end

      it 'returns "expired" when expired less than 120 days ago' do
        travel_to Time.zone.parse('2026-01-08 12:00:00 UTC') do
          # Expiration was 60 days ago (within the 120-day window)
          expiration_date = Time.zone.parse('2025-11-09 00:00:00 UTC').iso8601
          resource = status_test_resource.merge(
            'status' => 'completed',
            'dispenseRequest' => {
              'validityPeriod' => { 'end' => expiration_date }
            }
          )

          result = subject.send(:normalize_to_legacy_vista_status, resource)
          expect(result).to eq('expired')
        end
      end

      it 'returns "discontinued" when there is no validityPeriod.end date' do
        resource = status_test_resource.merge(
          'status' => 'completed',
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => {}
          }
        )

        result = subject.send(:normalize_to_legacy_vista_status, resource)
        expect(result).to eq('discontinued')
      end
    end

    context 'when MedicationRequest status is entered-in-error' do
      it 'returns "discontinued"' do
        resource = status_test_resource.merge('status' => 'entered-in-error')

        result = subject.send(:normalize_to_legacy_vista_status, resource)
        expect(result).to eq('discontinued')
      end
    end

    context 'when MedicationRequest status is stopped' do
      it 'returns "discontinued"' do
        resource = status_test_resource.merge('status' => 'stopped')

        result = subject.send(:normalize_to_legacy_vista_status, resource)
        expect(result).to eq('discontinued')
      end
    end

    context 'when MedicationRequest status is draft' do
      it 'returns "pending"' do
        resource = status_test_resource.merge('status' => 'draft')

        result = subject.send(:normalize_to_legacy_vista_status, resource)
        expect(result).to eq('pending')
      end
    end

    context 'when MedicationRequest status is unknown' do
      it 'returns "unknown"' do
        resource = status_test_resource.merge('status' => 'unknown')

        result = subject.send(:normalize_to_legacy_vista_status, resource)
        expect(result).to eq('unknown')
      end
    end

    context 'when MedicationRequest status is unexpected' do
      it 'returns "unknown" and logs a warning' do
        resource = status_test_resource.merge('status' => 'unexpected-status')

        expect(Rails.logger).to receive(:warn).with('Unexpected MedicationRequest status: unexpected-status')

        result = subject.send(:normalize_to_legacy_vista_status, resource)
        expect(result).to eq('unknown')
      end
    end

    it 'logs normalization details with last 3 digits of prescription ID only' do
      expect(Rails.logger).to receive(:info).with(hash_including(
                                                    message: 'Oracle Health status normalized',
                                                    prescription_id_suffix: '123',
                                                    original_status: 'active',
                                                    normalized_status: 'active',
                                                    service: 'unified_health_data'
                                                  ))

      subject.send(:normalize_to_legacy_vista_status, status_test_resource)
    end
  end

  describe '#most_recent_dispense_in_progress?' do
    it 'returns true when a dispense has preparation status' do
      resource = {
        'contained' => [
          { 'resourceType' => 'MedicationDispense', 'status' => 'preparation' }
        ]
      }

      expect(subject.send(:most_recent_dispense_in_progress?, resource)).to be true
    end

    it 'returns true when a dispense has in-progress status' do
      resource = {
        'contained' => [
          { 'resourceType' => 'MedicationDispense', 'status' => 'in-progress' }
        ]
      }

      expect(subject.send(:most_recent_dispense_in_progress?, resource)).to be true
    end

    it 'returns true when a dispense has on-hold status' do
      resource = {
        'contained' => [
          { 'resourceType' => 'MedicationDispense', 'status' => 'on-hold' }
        ]
      }

      expect(subject.send(:most_recent_dispense_in_progress?, resource)).to be true
    end

    it 'returns false when all dispenses are completed' do
      resource = {
        'contained' => [
          { 'resourceType' => 'MedicationDispense', 'status' => 'completed' },
          { 'resourceType' => 'MedicationDispense', 'status' => 'completed' }
        ]
      }

      expect(subject.send(:most_recent_dispense_in_progress?, resource)).to be false
    end

    it 'returns false when no dispenses exist' do
      resource = { 'contained' => [] }

      expect(subject.send(:most_recent_dispense_in_progress?, resource)).to be false
    end

    it 'returns false when contained is nil' do
      resource = {}

      expect(subject.send(:most_recent_dispense_in_progress?, resource)).to be false
    end

    it 'returns true when most recent dispense is in-progress even if older ones are completed' do
      resource = {
        'contained' => [
          {
            'resourceType' => 'MedicationDispense',
            'status' => 'completed',
            'whenHandedOver' => 2.days.ago.utc.iso8601
          },
          {
            'resourceType' => 'MedicationDispense',
            'status' => 'in-progress',
            'whenHandedOver' => 1.day.ago.utc.iso8601
          }
        ]
      }

      expect(subject.send(:most_recent_dispense_in_progress?, resource)).to be true
    end

    it 'returns false when most recent dispense is completed even if older ones are in-progress' do
      resource = {
        'contained' => [
          {
            'resourceType' => 'MedicationDispense',
            'status' => 'in-progress',
            'whenHandedOver' => 2.days.ago.utc.iso8601
          },
          {
            'resourceType' => 'MedicationDispense',
            'status' => 'completed',
            'whenHandedOver' => 1.day.ago.utc.iso8601
          }
        ]
      }

      expect(subject.send(:most_recent_dispense_in_progress?, resource)).to be false
    end
  end

  describe '#parse_expiration_date_utc' do
    it 'parses valid ISO8601 date to UTC time' do
      resource = {
        'dispenseRequest' => {
          'validityPeriod' => { 'end' => '2025-12-31T23:59:59Z' }
        }
      }

      result = subject.send(:parse_expiration_date_utc, resource)
      expect(result).to be_a(Time)
      expect(result.zone).to eq('UTC')
    end

    it 'returns nil when expiration date is missing' do
      resource = { 'dispenseRequest' => {} }

      result = subject.send(:parse_expiration_date_utc, resource)
      expect(result).to be_nil
    end

    it 'returns nil when dispenseRequest is missing' do
      resource = {}

      result = subject.send(:parse_expiration_date_utc, resource)
      expect(result).to be_nil
    end

    it 'returns nil and logs warning for invalid date' do
      resource = {
        'dispenseRequest' => {
          'validityPeriod' => { 'end' => 'invalid-date' }
        }
      }

      expect(Rails.logger).to receive(:warn).with(/Failed to parse expiration date/)

      result = subject.send(:parse_expiration_date_utc, resource)
      expect(result).to be_nil
    end
  end

  describe '#normalize_active_status' do
    it 'returns "discontinued" when expired more than 120 days ago' do
      expiration_date = 121.days.ago.utc
      result = subject.send(:normalize_active_status, 3, expiration_date, false)
      expect(result).to eq('discontinued')
    end

    it 'returns "expired" when no refills remaining' do
      expiration_date = 1.month.from_now.utc
      result = subject.send(:normalize_active_status, 0, expiration_date, false)
      expect(result).to eq('expired')
    end

    it 'returns "refillinprocess" when has in-progress dispense' do
      expiration_date = 1.month.from_now.utc
      result = subject.send(:normalize_active_status, 3, expiration_date, true)
      expect(result).to eq('refillinprocess')
    end

    it 'returns "active" when no special conditions apply' do
      expiration_date = 1.month.from_now.utc
      result = subject.send(:normalize_active_status, 3, expiration_date, false)
      expect(result).to eq('active')
    end

    it 'returns "active" when expiration date is nil' do
      result = subject.send(:normalize_active_status, 3, nil, false)
      expect(result).to eq('active')
    end
  end

  describe '#normalize_completed_status' do
    it 'returns "discontinued" when expired more than 120 days ago' do
      expiration_date = 121.days.ago.utc
      result = subject.send(:normalize_completed_status, expiration_date)
      expect(result).to eq('discontinued')
    end

    it 'returns "expired" when expired less than 120 days ago' do
      expiration_date = 60.days.ago.utc
      result = subject.send(:normalize_completed_status, expiration_date)
      expect(result).to eq('expired')
    end

    it 'returns "discontinued" when expiration date is nil' do
      result = subject.send(:normalize_completed_status, nil)
      expect(result).to eq('discontinued')
    end
  end

  describe '#extract_refill_status' do
    context 'when Task resources indicate a submitted refill' do
      it 'returns "submitted" when a valid Task with status=requested exists and no subsequent dispense' do
        resource = base_resource.merge(
          'id' => '12345',
          'status' => 'active',
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T21:05:53.000Z' }
            }
          ]
        )
        dispenses_data = []

        result = subject.send(:extract_refill_status, resource, dispenses_data)

        expect(result).to eq('submitted')
      end

      it 'returns "submitted" with multiple tasks when most recent has no subsequent dispense' do
        resource = base_resource.merge(
          'id' => '12345',
          'status' => 'active',
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-20T10:00:00.000Z' }
            },
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T21:05:53.000Z' }
            }
          ]
        )
        # Dispenses before the most recent task
        dispenses_data = [
          { when_prepared: '2025-06-19T12:00:00.000Z', when_handed_over: '2025-06-19T14:00:00.000Z' }
        ]

        result = subject.send(:extract_refill_status, resource, dispenses_data)

        expect(result).to eq('submitted')
      end
    end

    context 'when Task resources have failed or do not qualify' do
      it 'returns normalized status when Task has status=failed' do
        resource = base_resource.merge(
          'id' => '12345',
          'status' => 'active',
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
          },
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'failed',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T21:05:53.000Z' }
            }
          ]
        )

        result = subject.send(:extract_refill_status, resource, [])

        expect(result).to eq('active')
      end

      it 'returns normalized status when Task has intent=refill instead of order' do
        resource = base_resource.merge(
          'id' => '12345',
          'status' => 'active',
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
          },
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'refill',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T21:05:53.000Z' }
            }
          ]
        )

        result = subject.send(:extract_refill_status, resource, [])

        expect(result).to eq('active')
      end

      it 'returns normalized status when Task focus reference does not match' do
        resource = base_resource.merge(
          'id' => '12345',
          'status' => 'active',
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
          },
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/99999' },
              'executionPeriod' => { 'start' => '2025-06-24T21:05:53.000Z' }
            }
          ]
        )

        result = subject.send(:extract_refill_status, resource, [])

        expect(result).to eq('active')
      end
    end

    context 'when a subsequent dispense exists after Task submission' do
      it 'returns normalized status when dispense whenPrepared is after task date' do
        resource = base_resource.merge(
          'id' => '12345',
          'status' => 'active',
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
          },
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T10:00:00.000Z' }
            }
          ]
        )
        dispenses_data = [
          { when_prepared: '2025-06-24T12:00:00.000Z', when_handed_over: nil }
        ]

        result = subject.send(:extract_refill_status, resource, dispenses_data)

        expect(result).to eq('active')
      end

      it 'returns normalized status when dispense whenHandedOver is after task date' do
        resource = base_resource.merge(
          'id' => '12345',
          'status' => 'active',
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
          },
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T10:00:00.000Z' }
            }
          ]
        )
        dispenses_data = [
          { when_prepared: nil, when_handed_over: '2025-06-25T12:00:00.000Z' }
        ]

        result = subject.send(:extract_refill_status, resource, dispenses_data)

        expect(result).to eq('active')
      end
    end

    context 'when no Task resources are present' do
      it 'returns normalized status based on MedicationRequest status' do
        resource = base_resource.merge(
          'id' => '12345',
          'status' => 'active',
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => { 'end' => 30.days.from_now.utc.iso8601 }
          },
          'contained' => []
        )

        result = subject.send(:extract_refill_status, resource, [])

        expect(result).to eq('active')
      end

      it 'returns "discontinued" for cancelled MedicationRequest without tasks' do
        resource = base_resource.merge(
          'id' => '12345',
          'status' => 'cancelled',
          'contained' => []
        )

        result = subject.send(:extract_refill_status, resource, [])

        expect(result).to eq('discontinued')
      end
    end

    context 'with mixed contained resources' do
      it 'only considers Task resources, ignores MedicationDispense' do
        resource = base_resource.merge(
          'id' => '12345',
          'status' => 'active',
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'status' => 'completed',
              'whenHandedOver' => '2025-01-15T10:00:00Z'
            },
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T21:05:53.000Z' }
            }
          ]
        )

        result = subject.send(:extract_refill_status, resource, [])

        expect(result).to eq('submitted')
      end
    end
  end

  describe '#map_refill_status_to_disp_status' do
    context 'with standard refill_status values' do
      it 'maps "active" to "Active"' do
        result = subject.send(:map_refill_status_to_disp_status, 'active', 'VA')
        expect(result).to eq('Active')
      end

      it 'maps "submitted" to "Active: Submitted"' do
        result = subject.send(:map_refill_status_to_disp_status, 'submitted', 'VA')
        expect(result).to eq('Active: Submitted')
      end

      it 'maps "refillinprocess" to "Active: Refill in Process"' do
        result = subject.send(:map_refill_status_to_disp_status, 'refillinprocess', 'VA')
        expect(result).to eq('Active: Refill in Process')
      end

      it 'maps "providerHold" to "Active: On hold"' do
        result = subject.send(:map_refill_status_to_disp_status, 'providerHold', 'VA')
        expect(result).to eq('Active: On hold')
      end

      it 'maps "discontinued" to "Discontinued"' do
        result = subject.send(:map_refill_status_to_disp_status, 'discontinued', 'VA')
        expect(result).to eq('Discontinued')
      end

      it 'maps "expired" to "Expired"' do
        result = subject.send(:map_refill_status_to_disp_status, 'expired', 'VA')
        expect(result).to eq('Expired')
      end

      it 'maps "unknown" to "Unknown"' do
        result = subject.send(:map_refill_status_to_disp_status, 'unknown', 'VA')
        expect(result).to eq('Unknown')
      end

      it 'maps "pending" to "Unknown"' do
        result = subject.send(:map_refill_status_to_disp_status, 'pending', 'VA')
        expect(result).to eq('Unknown')
      end
    end

    context 'with Non-VA prescriptions' do
      it 'maps "active" + "NV" source to "Active: Non-VA"' do
        result = subject.send(:map_refill_status_to_disp_status, 'active', 'NV')
        expect(result).to eq('Active: Non-VA')
      end

      it 'does not apply Non-VA mapping to non-active statuses' do
        result = subject.send(:map_refill_status_to_disp_status, 'expired', 'NV')
        expect(result).to eq('Expired')
      end

      it 'does not apply Non-VA mapping to VA prescriptions' do
        result = subject.send(:map_refill_status_to_disp_status, 'active', 'VA')
        expect(result).to eq('Active')
      end
    end

    context 'with unexpected refill_status values' do
      before do
        allow(Rails.logger).to receive(:warn)
      end

      it 'returns "Unknown" and logs a warning' do
        result = subject.send(:map_refill_status_to_disp_status, 'unexpected_status', 'VA')
        expect(result).to eq('Unknown')
        expect(Rails.logger).to have_received(:warn)
          .with('Unexpected refill_status for disp_status mapping: unexpected_status')
      end
    end
  end

  describe '#parse with disp_status' do
    context 'when parsing a VA prescription with active status' do
      let(:active_va_resource) do
        base_resource.merge(
          'status' => 'active',
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'discharge' }] }
          ],
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => {
              'end' => 30.days.from_now.utc.iso8601
            }
          },
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'status' => 'completed',
              'whenHandedOver' => '2025-01-29T10:00:00Z'
            }
          ]
        )
      end

      it 'sets disp_status to "Active"' do
        result = subject.parse(active_va_resource)
        expect(result.disp_status).to eq('Active')
      end
    end

    context 'when parsing a Non-VA prescription with active status' do
      let(:active_nv_resource) do
        base_resource.merge(
          'status' => 'active',
          'reportedBoolean' => true,
          'intent' => 'plan',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'patientspecified' }] }
          ],
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => {
              'end' => 30.days.from_now.utc.iso8601
            }
          },
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'status' => 'completed',
              'whenHandedOver' => '2025-01-29T10:00:00Z'
            }
          ]
        )
      end

      it 'sets disp_status to "Active: Non-VA"' do
        result = subject.parse(active_nv_resource)
        expect(result.disp_status).to eq('Active: Non-VA')
      end
    end

    context 'when parsing a prescription with on-hold status' do
      let(:on_hold_resource) do
        base_resource.merge('status' => 'on-hold')
      end

      it 'sets disp_status to "Active: On hold"' do
        result = subject.parse(on_hold_resource)
        expect(result.disp_status).to eq('Active: On hold')
      end
    end

    context 'when parsing a prescription with completed status' do
      let(:completed_resource) do
        base_resource.merge(
          'status' => 'completed',
          'dispenseRequest' => {
            'validityPeriod' => {
              'end' => 60.days.ago.utc.iso8601
            }
          }
        )
      end

      it 'sets disp_status to "Expired"' do
        result = subject.parse(completed_resource)
        expect(result.disp_status).to eq('Expired')
      end
    end

    context 'when parsing a prescription with discontinued status' do
      let(:discontinued_resource) do
        base_resource.merge('status' => 'cancelled')
      end

      it 'sets disp_status to "Discontinued"' do
        result = subject.parse(discontinued_resource)
        expect(result.disp_status).to eq('Discontinued')
      end
    end

    context 'when parsing a prescription with in-progress dispense' do
      let(:refill_in_process_resource) do
        base_resource.merge(
          'status' => 'active',
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3
          },
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'status' => 'in-progress',
              'whenHandedOver' => '2025-01-29T10:00:00Z'
            }
          ]
        )
      end

      it 'sets disp_status to "Active: Refill in Process"' do
        result = subject.parse(refill_in_process_resource)
        expect(result.disp_status).to eq('Active: Refill in Process')
      end
    end

    context 'when parsing a prescription with Task resources indicating submitted refill' do
      let(:submitted_refill_resource) do
        base_resource.merge(
          'id' => '12345',
          'status' => 'active',
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => {
              'end' => 30.days.from_now.utc.iso8601
            }
          },
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T21:05:53.000Z' }
            }
          ]
        )
      end

      it 'sets refill_status to "submitted"' do
        result = subject.parse(submitted_refill_resource)
        expect(result.refill_status).to eq('submitted')
      end

      it 'sets disp_status to "Active: Submitted"' do
        result = subject.parse(submitted_refill_resource)
        expect(result.disp_status).to eq('Active: Submitted')
      end

      it 'sets refill_submit_date from Task executionPeriod.start' do
        result = subject.parse(submitted_refill_resource)
        expect(result.refill_submit_date).to eq('2025-06-24T21:05:53.000Z')
      end
    end

    context 'when parsing a prescription with failed Task resource' do
      let(:failed_task_resource) do
        base_resource.merge(
          'id' => '12345',
          'status' => 'active',
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'discharge' }] }
          ],
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => {
              'end' => 30.days.from_now.utc.iso8601
            }
          },
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'failed',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T21:05:53.000Z' }
            }
          ]
        )
      end

      it 'sets refill_status to "active" (not submitted)' do
        result = subject.parse(failed_task_resource)
        expect(result.refill_status).to eq('active')
      end

      it 'sets disp_status to "Active" (not "Active: Submitted")' do
        result = subject.parse(failed_task_resource)
        expect(result.disp_status).to eq('Active')
      end

      it 'does not set refill_submit_date' do
        result = subject.parse(failed_task_resource)
        expect(result.refill_submit_date).to be_nil
      end
    end

    context 'when Task exists but dispense occurred after task submission' do
      let(:task_with_subsequent_dispense_resource) do
        base_resource.merge(
          'id' => '12345',
          'status' => 'active',
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'discharge' }] }
          ],
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => {
              'end' => 30.days.from_now.utc.iso8601
            }
          },
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T10:00:00.000Z' }
            },
            {
              'resourceType' => 'MedicationDispense',
              'status' => 'completed',
              'whenPrepared' => '2025-06-24T12:00:00.000Z',
              'whenHandedOver' => '2025-06-24T14:00:00.000Z'
            }
          ]
        )
      end

      it 'sets refill_status to "active" because dispense fulfilled the task' do
        result = subject.parse(task_with_subsequent_dispense_resource)
        expect(result.refill_status).to eq('active')
      end

      it 'sets disp_status to "Active"' do
        result = subject.parse(task_with_subsequent_dispense_resource)
        expect(result.disp_status).to eq('Active')
      end

      it 'does not set refill_submit_date' do
        result = subject.parse(task_with_subsequent_dispense_resource)
        expect(result.refill_submit_date).to be_nil
      end
    end

    context 'when parsing prescription with both Task and MedicationDispense (dispense before task)' do
      let(:task_after_dispense_resource) do
        base_resource.merge(
          'id' => '12345',
          'status' => 'active',
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => {
              'end' => 30.days.from_now.utc.iso8601
            }
          },
          'contained' => [
            {
              'resourceType' => 'MedicationDispense',
              'status' => 'completed',
              'whenPrepared' => '2025-06-20T12:00:00.000Z',
              'whenHandedOver' => '2025-06-20T14:00:00.000Z'
            },
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T10:00:00.000Z' }
            }
          ]
        )
      end

      it 'sets refill_status to "submitted" because task is after dispense' do
        result = subject.parse(task_after_dispense_resource)
        expect(result.refill_status).to eq('submitted')
      end

      it 'sets disp_status to "Active: Submitted"' do
        result = subject.parse(task_after_dispense_resource)
        expect(result.disp_status).to eq('Active: Submitted')
      end

      it 'sets refill_submit_date from Task' do
        result = subject.parse(task_after_dispense_resource)
        expect(result.refill_submit_date).to eq('2025-06-24T10:00:00.000Z')
      end
    end

    context 'when parsing prescription with multiple Task resources' do
      let(:multiple_tasks_resource) do
        base_resource.merge(
          'id' => '12345',
          'status' => 'active',
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => {
              'end' => 30.days.from_now.utc.iso8601
            }
          },
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-20T10:00:00.000Z' }
            },
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T21:05:53.000Z' }
            }
          ]
        )
      end

      it 'uses most recent task for refill_submit_date' do
        result = subject.parse(multiple_tasks_resource)
        expect(result.refill_submit_date).to eq('2025-06-24T21:05:53.000Z')
      end

      it 'sets refill_status to "submitted"' do
        result = subject.parse(multiple_tasks_resource)
        expect(result.refill_status).to eq('submitted')
      end
    end
  end

  describe '#task_references_medication_request?' do
    it 'returns true when Task.focus.reference matches MedicationRequest/<id>' do
      task = {
        'focus' => {
          'reference' => 'MedicationRequest/12345'
        }
      }
      result = subject.send(:task_references_medication_request?, task, '12345')
      expect(result).to be true
    end

    it 'returns false when Task.focus.reference does not match' do
      task = {
        'focus' => {
          'reference' => 'MedicationRequest/99999'
        }
      }
      result = subject.send(:task_references_medication_request?, task, '12345')
      expect(result).to be false
    end

    it 'returns false when focus reference is missing' do
      task = {}
      result = subject.send(:task_references_medication_request?, task, '12345')
      expect(result).to be false
    end

    it 'returns false when medication_request_id is nil' do
      task = {
        'focus' => {
          'reference' => 'MedicationRequest/12345'
        }
      }
      result = subject.send(:task_references_medication_request?, task, nil)
      expect(result).to be false
    end
  end

  describe '#extract_refill_submission_metadata_from_tasks' do
    context 'when Task resources are present in MedicationRequest' do
      it 'extracts refill_submit_date from most recent successful Task resource with status=requested' do
        resource = base_resource.merge(
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T21:05:53.000Z' }
            }
          ]
        )

        metadata = subject.send(:extract_refill_submission_metadata_from_tasks, resource, [])

        expect(metadata[:refill_submit_date]).to eq('2025-06-24T21:05:53.000Z')
      end

      it 'ignores failed Task resources' do
        resource = base_resource.merge(
          'id' => '20848812135',
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'failed',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/20848812135' },
              'executionPeriod' => { 'start' => '2025-11-18T23:18:20+00:00' }
            }
          ]
        )

        metadata = subject.send(:extract_refill_submission_metadata_from_tasks, resource, [])

        expect(metadata).to eq({})
      end

      it 'ignores in-progress Task resources (only requested status is valid)' do
        resource = base_resource.merge(
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'in-progress',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T21:05:53.000Z' }
            }
          ]
        )

        metadata = subject.send(:extract_refill_submission_metadata_from_tasks, resource, [])

        expect(metadata).to eq({})
      end

      it 'ignores Task resources with intent=refill' do
        resource = base_resource.merge(
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'refill',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T21:05:53.000Z' }
            }
          ]
        )

        metadata = subject.send(:extract_refill_submission_metadata_from_tasks, resource, [])

        expect(metadata).to eq({})
      end

      it 'ignores Task resources with non-matching focus reference' do
        resource = base_resource.merge(
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/99999' },
              'executionPeriod' => { 'start' => '2025-06-24T21:05:53.000Z' }
            }
          ]
        )

        metadata = subject.send(:extract_refill_submission_metadata_from_tasks, resource, [])

        expect(metadata).to eq({})
      end

      it 'returns most recent successful task when multiple tasks exist' do
        resource = base_resource.merge(
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-20T10:00:00.000Z' }
            },
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T21:05:53.000Z' }
            }
          ]
        )

        metadata = subject.send(:extract_refill_submission_metadata_from_tasks, resource, [])

        expect(metadata[:refill_submit_date]).to eq('2025-06-24T21:05:53.000Z')
      end

      it 'handles tasks without execution_period_start gracefully' do
        resource = base_resource.merge(
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' }
            }
          ]
        )

        metadata = subject.send(:extract_refill_submission_metadata_from_tasks, resource, [])

        expect(metadata).to eq({})
      end

      it 'handles invalid date format gracefully by returning empty hash' do
        resource = base_resource.merge(
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => 'invalid-date' }
            }
          ]
        )

        metadata = subject.send(:extract_refill_submission_metadata_from_tasks, resource, [])

        expect(metadata).to eq({})
      end
    end

    context 'when a subsequent dispense exists' do
      it 'returns empty metadata when dispense whenPrepared is after task submit date' do
        resource = base_resource.merge(
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T10:00:00.000Z' }
            }
          ]
        )
        dispenses_data = [
          {
            when_prepared: '2025-06-24T12:00:00.000Z',
            when_handed_over: nil
          }
        ]

        metadata = subject.send(:extract_refill_submission_metadata_from_tasks, resource, dispenses_data)

        expect(metadata).to eq({})
      end

      it 'returns empty metadata when dispense whenHandedOver is after task submit date' do
        resource = base_resource.merge(
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T10:00:00.000Z' }
            }
          ]
        )
        dispenses_data = [
          {
            when_prepared: nil,
            when_handed_over: '2025-06-25T12:00:00.000Z'
          }
        ]

        metadata = subject.send(:extract_refill_submission_metadata_from_tasks, resource, dispenses_data)

        expect(metadata).to eq({})
      end

      it 'returns refill_submit_date when dispense dates are before task submit date' do
        resource = base_resource.merge(
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T10:00:00.000Z' }
            }
          ]
        )
        dispenses_data = [
          {
            when_prepared: '2025-06-20T12:00:00.000Z',
            when_handed_over: '2025-06-21T12:00:00.000Z'
          }
        ]

        metadata = subject.send(:extract_refill_submission_metadata_from_tasks, resource, dispenses_data)

        expect(metadata[:refill_submit_date]).to eq('2025-06-24T10:00:00.000Z')
      end

      it 'returns refill_submit_date when no dispenses have dates' do
        resource = base_resource.merge(
          'id' => '12345',
          'contained' => [
            {
              'resourceType' => 'Task',
              'status' => 'requested',
              'intent' => 'order',
              'focus' => { 'reference' => 'MedicationRequest/12345' },
              'executionPeriod' => { 'start' => '2025-06-24T10:00:00.000Z' }
            }
          ]
        )
        dispenses_data = [
          {
            when_prepared: nil,
            when_handed_over: nil
          }
        ]

        metadata = subject.send(:extract_refill_submission_metadata_from_tasks, resource, dispenses_data)

        expect(metadata[:refill_submit_date]).to eq('2025-06-24T10:00:00.000Z')
      end
    end

    context 'when no Task resources are present' do
      it 'returns empty metadata hash when contained is empty' do
        resource = base_resource.merge('contained' => [])

        metadata = subject.send(:extract_refill_submission_metadata_from_tasks, resource, [])

        expect(metadata).to eq({})
      end

      it 'returns empty metadata hash when contained is nil' do
        resource = base_resource.merge('contained' => nil)

        metadata = subject.send(:extract_refill_submission_metadata_from_tasks, resource, [])

        expect(metadata).to eq({})
      end
    end
  end

  describe '#subsequent_dispense?' do
    it 'returns true when dispense whenPrepared is after task date' do
      task_submit_date = '2025-06-24T10:00:00.000Z'
      dispenses_data = [
        {
          when_prepared: '2025-06-24T12:00:00.000Z',
          when_handed_over: nil
        }
      ]

      result = subject.send(:subsequent_dispense?, task_submit_date, dispenses_data)

      expect(result).to be true
    end

    it 'returns true when dispense whenHandedOver is after task date' do
      task_submit_date = '2025-06-24T10:00:00.000Z'
      dispenses_data = [
        {
          when_prepared: nil,
          when_handed_over: '2025-06-25T12:00:00.000Z'
        }
      ]

      result = subject.send(:subsequent_dispense?, task_submit_date, dispenses_data)

      expect(result).to be true
    end

    it 'returns false when all dispense dates are before task date' do
      task_submit_date = '2025-06-24T10:00:00.000Z'
      dispenses_data = [
        {
          when_prepared: '2025-06-20T12:00:00.000Z',
          when_handed_over: '2025-06-21T12:00:00.000Z'
        }
      ]

      result = subject.send(:subsequent_dispense?, task_submit_date, dispenses_data)

      expect(result).to be false
    end

    it 'returns false when dispenses have no dates' do
      task_submit_date = '2025-06-24T10:00:00.000Z'
      dispenses_data = [
        {
          when_prepared: nil,
          when_handed_over: nil
        }
      ]

      result = subject.send(:subsequent_dispense?, task_submit_date, dispenses_data)

      expect(result).to be false
    end

    it 'returns false when dispenses_data is empty' do
      task_submit_date = '2025-06-24T10:00:00.000Z'

      result = subject.send(:subsequent_dispense?, task_submit_date, [])

      expect(result).to be false
    end

    it 'returns false when dispenses_data is nil' do
      task_submit_date = '2025-06-24T10:00:00.000Z'

      result = subject.send(:subsequent_dispense?, task_submit_date, nil)

      expect(result).to be false
    end

    it 'returns false when task_submit_date is nil' do
      dispenses_data = [
        {
          when_prepared: '2025-06-24T12:00:00.000Z',
          when_handed_over: nil
        }
      ]

      result = subject.send(:subsequent_dispense?, nil, dispenses_data)

      expect(result).to be false
    end

    context 'with multiple dispenses' do
      it 'iterates all dispenses and returns true when last dispense has date after task date' do
        task_submit_date = '2025-06-24T10:00:00.000Z'
        dispenses_data = [
          { when_prepared: '2025-06-20T12:00:00.000Z', when_handed_over: nil },
          { when_prepared: '2025-06-22T12:00:00.000Z', when_handed_over: nil },
          { when_prepared: '2025-06-26T12:00:00.000Z', when_handed_over: nil } # After task date
        ]

        result = subject.send(:subsequent_dispense?, task_submit_date, dispenses_data)

        expect(result).to be true
      end

      it 'iterates all dispenses and returns true when middle dispense has date after task date' do
        task_submit_date = '2025-06-24T10:00:00.000Z'
        dispenses_data = [
          { when_prepared: '2025-06-20T12:00:00.000Z', when_handed_over: nil },
          { when_prepared: '2025-06-26T12:00:00.000Z', when_handed_over: nil }, # After task date
          { when_prepared: '2025-06-22T12:00:00.000Z', when_handed_over: nil }
        ]

        result = subject.send(:subsequent_dispense?, task_submit_date, dispenses_data)

        expect(result).to be true
      end

      it 'iterates all dispenses and returns false when no dispense has date after task date' do
        task_submit_date = '2025-06-24T10:00:00.000Z'
        dispenses_data = [
          { when_prepared: '2025-06-20T12:00:00.000Z', when_handed_over: nil },
          { when_prepared: '2025-06-22T12:00:00.000Z', when_handed_over: nil },
          { when_prepared: '2025-06-23T12:00:00.000Z', when_handed_over: nil }
        ]

        result = subject.send(:subsequent_dispense?, task_submit_date, dispenses_data)

        expect(result).to be false
      end

      it 'checks whenHandedOver for each dispense when whenPrepared is nil' do
        task_submit_date = '2025-06-24T10:00:00.000Z'
        dispenses_data = [
          { when_prepared: nil, when_handed_over: '2025-06-20T12:00:00.000Z' },
          { when_prepared: nil, when_handed_over: '2025-06-22T12:00:00.000Z' },
          { when_prepared: nil, when_handed_over: '2025-06-26T12:00:00.000Z' } # After task date
        ]

        result = subject.send(:subsequent_dispense?, task_submit_date, dispenses_data)

        expect(result).to be true
      end
    end
  end
end
