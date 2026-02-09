# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events/oracle_health'
require 'unique_user_events/event_registry'

RSpec.describe UniqueUserEvents::OracleHealth do
  let(:user) { double('User') }
  let(:event_name) { UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ALLERGIES_ACCESSED }
  let(:non_tracked_event) { 'some_other_event' }

  before do
    allow(Flipper).to receive(:enabled?).with(:mhv_oh_unique_user_metrics_logging).and_return(true)
  end

  describe '.generate_events' do
    context 'when mhv_oh_unique_user_metrics_logging is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_oh_unique_user_metrics_logging).and_return(false)
        allow(user).to receive(:vha_facility_ids).and_return(%w[757])
      end

      it 'returns empty array without generating OH events' do
        result = described_class.generate_events(user:, event_name:)

        expect(result).to eq([])
      end
    end

    context 'when event is tracked for Oracle Health' do
      context 'when user has matching facilities' do
        before do
          allow(user).to receive(:vha_facility_ids).and_return(%w[757 200])
        end

        it 'generates OH events for matching facilities' do
          result = described_class.generate_events(user:, event_name:)

          expect(result).to contain_exactly("#{event_name}_oh_site_757")
        end
      end

      context 'when user has only the tracked facility' do
        before do
          allow(user).to receive(:vha_facility_ids).and_return(%w[757])
        end

        it 'generates OH event for the matching facility' do
          result = described_class.generate_events(user:, event_name:)

          expect(result).to contain_exactly("#{event_name}_oh_site_757")
        end
      end

      context 'when user has no matching facilities' do
        before do
          allow(user).to receive(:vha_facility_ids).and_return(%w[200 300])
        end

        it 'returns empty array' do
          result = described_class.generate_events(user:, event_name:)

          expect(result).to eq([])
        end
      end

      context 'when user has nil facility IDs' do
        before do
          allow(user).to receive(:vha_facility_ids).and_return(nil)
        end

        it 'returns empty array' do
          result = described_class.generate_events(user:, event_name:)

          expect(result).to eq([])
        end
      end
    end

    context 'when event is not tracked for Oracle Health' do
      before do
        allow(user).to receive(:vha_facility_ids).and_return(['757'])
      end

      it 'returns empty array' do
        result = described_class.generate_events(user:, event_name: non_tracked_event)

        expect(result).to eq([])
      end
    end
  end

  describe '.get_user_tracked_facilities' do
    it 'is a private method' do
      expect(described_class.private_methods).to include(:get_user_tracked_facilities)
    end
  end

  describe '.generate_events with event_facility_ids' do
    let(:event_name) { 'prescriptions_refill_requested' }

    context 'when mhv_oh_unique_user_metrics_logging is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_oh_unique_user_metrics_logging).and_return(false)
        allow(user).to receive(:cerner_facility_ids).and_return(%w[757])
      end

      it 'returns empty array without generating OH events' do
        result = described_class.generate_events(
          user:,
          event_name:,
          event_facility_ids: %w[757 688]
        )

        expect(result).to eq([])
      end
    end

    context 'when facility IDs match tracked facilities and user cerner_facility_ids' do
      before do
        allow(user).to receive(:cerner_facility_ids).and_return(%w[757])
      end

      it 'generates OH events for matching facilities' do
        result = described_class.generate_events(
          user:,
          event_name:,
          event_facility_ids: %w[757 688]
        )

        expect(result).to contain_exactly('prescriptions_refill_requested_oh_757')
      end

      it 'generates OH events for multiple matching facilities' do
        # Temporarily stub TRACKED_FACILITY_IDS to include multiple facilities for this test
        stub_const('UniqueUserEvents::OracleHealth::TRACKED_FACILITY_IDS', %w[757 688])
        allow(user).to receive(:cerner_facility_ids).and_return(%w[757 688])

        result = described_class.generate_events(
          user:,
          event_name:,
          event_facility_ids: %w[757 688 999]
        )

        expect(result).to contain_exactly(
          'prescriptions_refill_requested_oh_757',
          'prescriptions_refill_requested_oh_688'
        )
      end
    end

    context 'when facility is tracked but user is not a cerner patient at that facility' do
      before do
        # User is not a cerner patient at 757
        allow(user).to receive(:cerner_facility_ids).and_return(%w[668])
      end

      it 'returns empty array' do
        result = described_class.generate_events(
          user:,
          event_name:,
          event_facility_ids: %w[757]
        )

        expect(result).to eq([])
      end
    end

    context 'when user is a cerner patient but facility is not tracked' do
      before do
        allow(user).to receive(:cerner_facility_ids).and_return(%w[999])
      end

      it 'returns empty array' do
        result = described_class.generate_events(
          user:,
          event_name:,
          event_facility_ids: %w[999]
        )

        expect(result).to eq([])
      end
    end

    context 'when no facility IDs match tracked facilities' do
      before do
        allow(user).to receive(:cerner_facility_ids).and_return(%w[757])
      end

      it 'returns empty array' do
        result = described_class.generate_events(
          user:,
          event_name:,
          event_facility_ids: %w[999 888]
        )

        expect(result).to eq([])
      end
    end

    context 'when facility IDs array is empty' do
      before do
        allow(user).to receive(:cerner_facility_ids).and_return(%w[757])
      end

      it 'returns empty array' do
        result = described_class.generate_events(
          user:,
          event_name:,
          event_facility_ids: []
        )

        expect(result).to eq([])
      end
    end

    context 'when user has nil cerner_facility_ids' do
      before do
        allow(user).to receive(:cerner_facility_ids).and_return(nil)
      end

      it 'returns empty array' do
        result = described_class.generate_events(
          user:,
          event_name:,
          event_facility_ids: %w[757]
        )

        expect(result).to eq([])
      end
    end

    context 'when facility IDs contain integers' do
      before do
        allow(user).to receive(:cerner_facility_ids).and_return(%w[757])
      end

      it 'normalizes to strings and matches' do
        result = described_class.generate_events(
          user:,
          event_name:,
          event_facility_ids: [757, 688]
        )

        expect(result).to contain_exactly('prescriptions_refill_requested_oh_757')
      end
    end

    context 'unlike user-based generate_events' do
      before do
        allow(user).to receive(:cerner_facility_ids).and_return(%w[757])
      end

      it 'does not check TRACKED_EVENTS - any event can be logged with explicit facilities' do
        # This event is NOT in TRACKED_EVENTS, but should still work with explicit facilities
        non_tracked_event = 'some_custom_event_not_in_tracked_list'

        result = described_class.generate_events(
          user:,
          event_name: non_tracked_event,
          event_facility_ids: %w[757]
        )

        expect(result).to contain_exactly("#{non_tracked_event}_oh_757")
      end
    end
  end

  describe '.filter_tracked_oh_facilities' do
    it 'is a private method' do
      expect(described_class.private_methods).to include(:filter_tracked_oh_facilities)
    end
  end

  describe 'all tracked events' do
    before do
      allow(user).to receive(:vha_facility_ids).and_return(['757'])
    end

    described_class::TRACKED_EVENTS.each do |tracked_event|
      it "generates OH events for #{tracked_event}" do
        result = described_class.generate_events(user:, event_name: tracked_event)

        expect(result).to contain_exactly("#{tracked_event}_oh_site_757")
      end
    end
  end
end
