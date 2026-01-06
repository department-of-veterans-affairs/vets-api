# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/oracle_health_refill_helper'
require 'unified_health_data/adapters/oracle_health_categorizer'
require 'unified_health_data/adapters/fhir_helpers'

describe UnifiedHealthData::Adapters::OracleHealthRefillHelper do
  subject { helper_class.new }

  let(:helper_class) do
    Class.new do
      include UnifiedHealthData::Adapters::OracleHealthRefillHelper
      include UnifiedHealthData::Adapters::OracleHealthCategorizer
      include UnifiedHealthData::Adapters::FhirHelpers

      # Stub extract_expiration_date since it's defined in the adapter
      def extract_expiration_date(resource)
        resource.dig('dispenseRequest', 'validityPeriod', 'end')
      end
    end
  end

  let(:base_resource) do
    {
      'resourceType' => 'MedicationRequest',
      'id' => '12345',
      'status' => 'active'
    }
  end

  let(:completed_dispense) do
    {
      'resourceType' => 'MedicationDispense',
      'status' => 'completed',
      'whenHandedOver' => '2025-01-01T10:00:00Z'
    }
  end

  let(:future_expiration_date) { 30.days.from_now.iso8601 }
  let(:past_expiration_date) { 30.days.ago.iso8601 }

  describe '#refillable?' do
    let(:refillable_resource) do
      base_resource.merge(
        'reportedBoolean' => false,
        'intent' => 'order',
        'category' => [
          { 'coding' => [{ 'code' => 'community' }] },
          { 'coding' => [{ 'code' => 'discharge' }] }
        ],
        'dispenseRequest' => {
          'numberOfRepeatsAllowed' => 3,
          'validityPeriod' => { 'end' => future_expiration_date }
        },
        'contained' => [completed_dispense]
      )
    end

    context 'when all conditions are met' do
      it 'returns true' do
        expect(subject.refillable?(refillable_resource, nil)).to be true
      end
    end

    context 'when medication is non-VA' do
      let(:non_va_resource) do
        base_resource.merge(
          'reportedBoolean' => true,
          'intent' => 'plan',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'patientspecified' }] }
          ],
          'status' => 'active',
          'dispenseRequest' => {
            'numberOfRepeatsAllowed' => 3,
            'validityPeriod' => { 'end' => future_expiration_date }
          },
          'contained' => [completed_dispense]
        )
      end

      it 'returns false' do
        expect(subject.refillable?(non_va_resource, nil)).to be false
      end
    end

    context 'when status is not active' do
      let(:inactive_resource) do
        refillable_resource.merge('status' => 'stopped')
      end

      it 'returns false' do
        expect(subject.refillable?(inactive_resource, nil)).to be false
      end
    end

    context 'when prescription is expired' do
      let(:expired_resource) do
        refillable_resource.deep_merge(
          'dispenseRequest' => {
            'validityPeriod' => { 'end' => past_expiration_date }
          }
        )
      end

      it 'returns false' do
        expect(subject.refillable?(expired_resource, nil)).to be false
      end
    end

    context 'when no refills remaining' do
      let(:no_refills_resource) do
        refillable_resource.deep_merge(
          'dispenseRequest' => { 'numberOfRepeatsAllowed' => 0 }
        )
      end

      it 'returns false' do
        expect(subject.refillable?(no_refills_resource, nil)).to be false
      end
    end

    context 'when no medication dispense exists' do
      let(:no_dispense_resource) do
        refillable_resource.merge('contained' => [])
      end

      it 'returns false' do
        expect(subject.refillable?(no_dispense_resource, nil)).to be false
      end
    end

    context 'when most recent dispense is in progress' do
      let(:in_progress_dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'status' => 'in-progress',
          'whenHandedOver' => '2025-01-02T10:00:00Z'
        }
      end

      let(:in_progress_resource) do
        refillable_resource.merge('contained' => [completed_dispense, in_progress_dispense])
      end

      it 'returns false' do
        expect(subject.refillable?(in_progress_resource, nil)).to be false
      end
    end

    context 'when refill_status is submitted' do
      it 'returns false' do
        expect(subject.refillable?(refillable_resource, 'submitted')).to be false
      end
    end
  end

  describe '#prescription_not_expired?' do
    context 'when expiration date is in the future' do
      let(:resource) do
        base_resource.merge(
          'dispenseRequest' => {
            'validityPeriod' => { 'end' => future_expiration_date }
          }
        )
      end

      it 'returns true' do
        expect(subject.prescription_not_expired?(resource)).to be true
      end
    end

    context 'when expiration date is in the past' do
      let(:resource) do
        base_resource.merge(
          'dispenseRequest' => {
            'validityPeriod' => { 'end' => past_expiration_date }
          }
        )
      end

      it 'returns false' do
        expect(subject.prescription_not_expired?(resource)).to be false
      end
    end

    context 'when expiration date is missing' do
      it 'returns false' do
        expect(subject.prescription_not_expired?(base_resource)).to be false
      end
    end

    context 'when expiration date is invalid' do
      let(:resource) do
        base_resource.merge(
          'dispenseRequest' => {
            'validityPeriod' => { 'end' => 'invalid-date' }
          }
        )
      end

      it 'returns false and logs warning' do
        expect(Rails.logger).to receive(:warn).with(/Invalid expiration date/)
        expect(subject.prescription_not_expired?(resource)).to be false
      end
    end

    context 'when expiration date is today' do
      let(:resource) do
        base_resource.merge(
          'dispenseRequest' => {
            'validityPeriod' => { 'end' => Time.zone.now.end_of_day.iso8601 }
          }
        )
      end

      it 'returns true (end of day is still in the future)' do
        expect(subject.prescription_not_expired?(resource)).to be true
      end
    end
  end

  describe '#extract_refill_remaining' do
    context 'when medication is non-VA' do
      let(:non_va_resource) do
        base_resource.merge(
          'reportedBoolean' => true,
          'intent' => 'plan',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'patientspecified' }] }
          ],
          'dispenseRequest' => { 'numberOfRepeatsAllowed' => 5 }
        )
      end

      it 'returns 0' do
        expect(subject.extract_refill_remaining(non_va_resource)).to eq(0)
      end
    end

    context 'with VA medication no completed dispenses' do
      let(:resource) do
        base_resource.merge(
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'discharge' }] }
          ],
          'dispenseRequest' => { 'numberOfRepeatsAllowed' => 3 }
        )
      end

      it 'returns the full number of repeats allowed' do
        expect(subject.extract_refill_remaining(resource)).to eq(3)
      end
    end

    context 'with VA medication and one dispense is completed (initial fill)' do
      let(:resource) do
        base_resource.merge(
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'discharge' }] }
          ],
          'dispenseRequest' => { 'numberOfRepeatsAllowed' => 3 },
          'contained' => [completed_dispense]
        )
      end

      it 'returns the full number of repeats (initial fill does not count)' do
        expect(subject.extract_refill_remaining(resource)).to eq(3)
      end
    end

    context 'with VA medication and multiple completed dispenses' do
      let(:second_dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'status' => 'completed',
          'whenHandedOver' => '2025-02-01T10:00:00Z'
        }
      end

      let(:third_dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'status' => 'completed',
          'whenHandedOver' => '2025-03-01T10:00:00Z'
        }
      end

      let(:resource) do
        base_resource.merge(
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'discharge' }] }
          ],
          'dispenseRequest' => { 'numberOfRepeatsAllowed' => 3 },
          'contained' => [completed_dispense, second_dispense, third_dispense]
        )
      end

      it 'subtracts completed dispenses minus one (for initial fill)' do
        # 3 completed, minus first fill = 2 used refills
        # 3 allowed - 2 used = 1 remaining
        expect(subject.extract_refill_remaining(resource)).to eq(1)
      end
    end

    context 'with VA medication and all refills are used' do
      let(:dispenses) do
        4.times.map do |i|
          {
            'resourceType' => 'MedicationDispense',
            'status' => 'completed',
            'whenHandedOver' => "2025-0#{i + 1}-01T10:00:00Z"
          }
        end
      end

      let(:resource) do
        base_resource.merge(
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'discharge' }] }
          ],
          'dispenseRequest' => { 'numberOfRepeatsAllowed' => 3 },
          'contained' => dispenses
        )
      end

      it 'returns 0' do
        # 4 completed, minus first fill = 3 used refills
        # 3 allowed - 3 used = 0 remaining
        expect(subject.extract_refill_remaining(resource)).to eq(0)
      end
    end

    context 'when numberOfRepeatsAllowed is missing' do
      let(:resource) do
        base_resource.merge(
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'discharge' }] }
          ],
          'dispenseRequest' => {}
        )
      end

      it 'returns 0' do
        expect(subject.extract_refill_remaining(resource)).to eq(0)
      end
    end

    context 'with non-completed dispenses' do
      let(:in_progress_dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'status' => 'in-progress',
          'whenHandedOver' => '2025-02-01T10:00:00Z'
        }
      end

      let(:resource) do
        base_resource.merge(
          'reportedBoolean' => false,
          'intent' => 'order',
          'category' => [
            { 'coding' => [{ 'code' => 'community' }] },
            { 'coding' => [{ 'code' => 'discharge' }] }
          ],
          'dispenseRequest' => { 'numberOfRepeatsAllowed' => 3 },
          'contained' => [completed_dispense, in_progress_dispense]
        )
      end

      it 'only counts completed dispenses' do
        # 1 completed (initial fill), in-progress not counted
        # 3 allowed - 0 used = 3 remaining
        expect(subject.extract_refill_remaining(resource)).to eq(3)
      end
    end
  end

  describe '#most_recent_dispense_in_progress?' do
    context 'when most recent dispense is completed' do
      let(:resource) do
        base_resource.merge('contained' => [completed_dispense])
      end

      it 'returns false' do
        expect(subject.most_recent_dispense_in_progress?(resource)).to be false
      end
    end

    context 'when most recent dispense is in preparation status' do
      let(:preparation_dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'status' => 'preparation',
          'whenHandedOver' => '2025-01-02T10:00:00Z'
        }
      end

      let(:resource) do
        base_resource.merge('contained' => [completed_dispense, preparation_dispense])
      end

      it 'returns true' do
        expect(subject.most_recent_dispense_in_progress?(resource)).to be true
      end
    end

    context 'when most recent dispense is in-progress status' do
      let(:in_progress_dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'status' => 'in-progress',
          'whenHandedOver' => '2025-01-02T10:00:00Z'
        }
      end

      let(:resource) do
        base_resource.merge('contained' => [completed_dispense, in_progress_dispense])
      end

      it 'returns true' do
        expect(subject.most_recent_dispense_in_progress?(resource)).to be true
      end
    end

    context 'when most recent dispense is on-hold status' do
      let(:on_hold_dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'status' => 'on-hold',
          'whenHandedOver' => '2025-01-02T10:00:00Z'
        }
      end

      let(:resource) do
        base_resource.merge('contained' => [completed_dispense, on_hold_dispense])
      end

      it 'returns true' do
        expect(subject.most_recent_dispense_in_progress?(resource)).to be true
      end
    end

    context 'when no dispenses exist' do
      it 'returns false' do
        expect(subject.most_recent_dispense_in_progress?(base_resource)).to be false
      end
    end

    context 'when contained is empty' do
      let(:resource) do
        base_resource.merge('contained' => [])
      end

      it 'returns false' do
        expect(subject.most_recent_dispense_in_progress?(resource)).to be false
      end
    end

    context 'when older dispense is in-progress but most recent is completed' do
      let(:old_in_progress_dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'status' => 'in-progress',
          'whenHandedOver' => '2024-12-01T10:00:00Z'
        }
      end

      let(:recent_completed_dispense) do
        {
          'resourceType' => 'MedicationDispense',
          'status' => 'completed',
          'whenHandedOver' => '2025-01-15T10:00:00Z'
        }
      end

      let(:resource) do
        base_resource.merge('contained' => [old_in_progress_dispense, recent_completed_dispense])
      end

      it 'returns false (only checks most recent)' do
        expect(subject.most_recent_dispense_in_progress?(resource)).to be false
      end
    end
  end
end
