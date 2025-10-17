# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events/oracle_health'

RSpec.describe UniqueUserEvents::OracleHealth do
  let(:user) { double('User') }
  let(:event_name) { 'mhv_sm_message_sent' }
  let(:non_tracked_event) { 'some_other_event' }

  describe '.generate_events' do
    context 'when event is tracked for Oracle Health' do
      context 'when user has matching facilities' do
        before do
          allow(user).to receive(:vha_facility_ids).and_return(%w[757 200])
        end

        it 'generates OH events for matching facilities' do
          result = described_class.generate_events(user:, event_name:)

          expect(result).to contain_exactly('mhv_sm_message_sent_oh_site_757')
        end
      end

      context 'when user has only the tracked facility' do
        before do
          allow(user).to receive(:vha_facility_ids).and_return(%w[757])
        end

        it 'generates OH event for the matching facility' do
          result = described_class.generate_events(user:, event_name:)

          expect(result).to contain_exactly('mhv_sm_message_sent_oh_site_757')
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
