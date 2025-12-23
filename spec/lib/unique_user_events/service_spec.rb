# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events'

RSpec.describe UniqueUserEvents::Service do
  let(:user) { double('User', user_account_uuid: SecureRandom.uuid, vha_facility_ids: []) }
  let(:user_id) { user.user_account_uuid }
  let(:event_name) { UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED }
  let(:oh_event_name) { UniqueUserEvents::EventRegistry::SECURE_MESSAGING_MESSAGE_SENT }

  describe '.log_event' do
    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
      allow(MHVMetricsUniqueUserEvent).to receive(:record_event)
      allow(described_class).to receive(:increment_statsd_counter)
      allow(StatsD).to receive(:increment)
      allow(UniqueUserEvents::OracleHealth).to receive(:generate_events).and_return([])
    end

    context 'when logging a regular event' do
      context 'when new event is created' do
        before do
          allow(MHVMetricsUniqueUserEvent).to receive(:record_event).and_return(true)
        end

        it 'returns array with created event result' do
          result = described_class.log_event(user:, event_name:)

          expect(result).to eq([{
                                 event_name:,
                                 status: 'created',
                                 new_event: true
                               }])
        end

        it 'records event and increments StatsD counter' do
          described_class.log_event(user:, event_name:)

          expect(MHVMetricsUniqueUserEvent).to have_received(:record_event).with(user_id:, event_name:)
          expect(described_class).to have_received(:increment_statsd_counter).with(event_name)
          expect(Rails.logger).to have_received(:info).with('UUM: New event logged', { user_id:, event_name: })
        end

        it 'increments events_to_log counter with correct count' do
          described_class.log_event(user:, event_name:)

          expect(StatsD).to have_received(:increment).with(
            'uum.unique_user_metrics.events_to_log',
            tags: ['count:1']
          )
        end
      end

      context 'when event already exists' do
        before do
          allow(MHVMetricsUniqueUserEvent).to receive(:record_event).and_return(false)
        end

        it 'returns array with exists event result' do
          result = described_class.log_event(user:, event_name:)

          expect(result).to eq([{
                                 event_name:,
                                 status: 'exists',
                                 new_event: false
                               }])
        end

        it 'does not increment StatsD counter' do
          described_class.log_event(user:, event_name:)

          expect(described_class).not_to have_received(:increment_statsd_counter)
        end
      end
    end

    context 'when logging Oracle Health events' do
      let(:oh_events) { ['mhv_sm_message_sent_oh_site_757'] }

      before do
        allow(UniqueUserEvents::OracleHealth).to receive(:generate_events).and_return(oh_events)
        allow(MHVMetricsUniqueUserEvent).to receive(:record_event).and_return(true)
      end

      it 'includes both original and OH events in results' do
        result = described_class.log_event(user:, event_name: oh_event_name)

        expect(result).to eq([
                               { event_name: oh_event_name, status: 'created', new_event: true },
                               { event_name: 'mhv_sm_message_sent_oh_site_757', status: 'created', new_event: true }
                             ])
      end

      it 'calls Oracle Health module to generate events' do
        described_class.log_event(user:, event_name: oh_event_name)

        expect(UniqueUserEvents::OracleHealth).to have_received(:generate_events).with(user:, event_name: oh_event_name)
      end

      it 'increments events_to_log counter with total count including OH events' do
        described_class.log_event(user:, event_name: oh_event_name)

        expect(StatsD).to have_received(:increment).with(
          'uum.unique_user_metrics.events_to_log',
          tags: ['count:2']
        )
      end
    end

    context 'when an exception occurs' do
      let(:error_message) { 'Something went wrong' }

      before do
        allow(MHVMetricsUniqueUserEvent).to receive(:record_event).and_raise(StandardError, error_message)
      end

      it 'returns error result array and logs error without raising' do
        result = described_class.log_event(user:, event_name:)

        expect(result).to eq([{
                               event_name:,
                               status: 'error',
                               new_event: false,
                               error: 'Failed to process event'
                             }])
        expect(Rails.logger).to have_received(:error)
          .with('UUM: Failed to log event', { user_id:, event_name:, error: error_message })
      end
    end

    context 'when event name is invalid' do
      let(:invalid_event_name) { 'invalid_unregistered_event' }

      it 'raises ArgumentError' do
        expect do
          described_class.log_event(user:, event_name: invalid_event_name)
        end.to raise_error(ArgumentError, /Invalid event name/)
      end

      it 'includes the invalid event name in error message' do
        expect do
          described_class.log_event(user:, event_name: invalid_event_name)
        end.to raise_error(ArgumentError, /invalid_unregistered_event/)
      end

      it 'includes list of valid events in error message' do
        expect do
          described_class.log_event(user:, event_name: invalid_event_name)
        end.to raise_error(ArgumentError, /Must be one of:/)
      end
    end
  end

  describe '.event_logged?' do
    before do
      allow(Rails.logger).to receive(:error)
      allow(MHVMetricsUniqueUserEvent).to receive(:event_exists?)
    end

    it 'delegates to model and returns result' do
      allow(MHVMetricsUniqueUserEvent).to receive(:event_exists?).and_return(true)

      result = described_class.event_logged?(user:, event_name:)

      expect(result).to be(true)
      expect(MHVMetricsUniqueUserEvent).to have_received(:event_exists?).with(user_id:, event_name:)
    end

    it 'returns false when model returns false' do
      allow(MHVMetricsUniqueUserEvent).to receive(:event_exists?).and_return(false)

      result = described_class.event_logged?(user:, event_name:)

      expect(result).to be(false)
    end

    context 'when an exception occurs' do
      let(:error_message) { 'Database error' }

      before do
        allow(MHVMetricsUniqueUserEvent).to receive(:event_exists?).and_raise(StandardError, error_message)
      end

      it 'returns false and logs error without raising' do
        result = described_class.event_logged?(user:, event_name:)

        expect(result).to be(false)
        expect(Rails.logger).to have_received(:error)
          .with('UUM: Failed to check event', { user_id:, event_name:, error: error_message })
      end
    end

    context 'when event name is invalid' do
      let(:invalid_event_name) { 'invalid_unregistered_event' }

      it 'raises ArgumentError' do
        expect do
          described_class.event_logged?(user:, event_name: invalid_event_name)
        end.to raise_error(ArgumentError, /Invalid event name/)
      end
    end
  end

  describe '.increment_statsd_counter' do
    before do
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    it 'increments StatsD counter with correct parameters' do
      described_class.send(:increment_statsd_counter, event_name)

      expect(StatsD).to have_received(:increment).with(
        'uum.unique_user_metrics.event',
        tags: ["event_name:#{event_name}"]
      )
    end

    context 'when StatsD increment fails' do
      let(:error_message) { 'StatsD connection error' }

      before do
        allow(StatsD).to receive(:increment).and_raise(StandardError, error_message)
      end

      it 'logs error without raising exception' do
        expect do
          described_class.send(:increment_statsd_counter, event_name)
        end.not_to raise_error

        expect(Rails.logger).to have_received(:error)
          .with('UUM: Failed to increment StatsD counter', { event_name:, error: error_message })
      end
    end
  end
end
