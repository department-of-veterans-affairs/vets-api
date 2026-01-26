# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events'

RSpec.describe UniqueUserEvents do
  let(:user) { double('User', user_account_uuid: SecureRandom.uuid) }
  let(:event_name) { UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED }

  describe '.log_event' do
    before do
      allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_async_buffering, user).and_return(false)
      allow(UniqueUserEvents::Service).to receive(:log_event)
      allow(StatsD).to receive(:measure)
    end

    context 'when async buffering is disabled' do
      it 'routes to synchronous processing' do
        expected_result = [{ event_name:, status: 'created', new_event: true }]
        allow(UniqueUserEvents::Service).to receive(:log_event).and_return(expected_result)

        result = described_class.log_event(user:, event_name:)

        expect(result).to eq(expected_result)
        expect(UniqueUserEvents::Service).to have_received(:log_event).with(user:, event_name:)
      end
    end

    context 'when async buffering is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_async_buffering, user).and_return(true)
        allow(UniqueUserEvents::EventRegistry).to receive(:validate_event!)
        allow(UniqueUserEvents::Service).to receive_messages(
          extract_user_id: user.user_account_uuid,
          get_all_events_to_log: [event_name],
          build_buffered_result: { event_name:, status: 'buffered', new_event: false }
        )
        allow(UniqueUserEvents::Buffer).to receive(:push)
      end

      it 'routes to asynchronous processing' do
        result = described_class.log_event(user:, event_name:)

        expect(result).to eq([{ event_name:, status: 'buffered', new_event: false }])
        expect(UniqueUserEvents::Buffer).to have_received(:push).with(
          user_id: user.user_account_uuid,
          event_name:
        )
        expect(UniqueUserEvents::Service).not_to have_received(:log_event)
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(false)
        allow(UniqueUserEvents::Service).to receive(:log_event)
      end

      it 'returns disabled result without calling service' do
        result = described_class.log_event(user:, event_name:)

        expect(result).to eq([{ event_name:, status: 'disabled', new_event: false }])
        expect(UniqueUserEvents::Service).not_to have_received(:log_event)
      end

      it 'does not measure performance metrics when disabled' do
        expect(StatsD).not_to receive(:measure)

        described_class.log_event(user:, event_name:)
      end
    end

    context 'when ArgumentError is raised' do
      before do
        allow(UniqueUserEvents::Service).to receive(:log_event).and_raise(ArgumentError, 'Invalid event')
      end

      it 're-raises the error' do
        expect { described_class.log_event(user:, event_name:) }.to raise_error(ArgumentError, 'Invalid event')
      end
    end

    context 'when other errors occur' do
      before do
        allow(UniqueUserEvents::Service).to receive(:log_event).and_raise(StandardError, 'Service error')
        allow(Rails.logger).to receive(:error)
      end

      it 'returns error result' do
        result = described_class.log_event(user:, event_name:)

        expect(result).to eq([{ event_name:, status: 'error', new_event: false, error: 'Failed to process event' }])
      end

      it 'logs the error' do
        described_class.log_event(user:, event_name:)

        expect(Rails.logger).to have_received(:error).with(/UUM: Failed during log_event/)
      end
    end
  end

  describe '.log_event_sync' do
    let(:expected_result) { [{ event_name:, status: 'created', new_event: true }] }

    before do
      allow(UniqueUserEvents::Service).to receive(:log_event).and_return(expected_result)
      allow(StatsD).to receive(:measure)
    end

    it 'calls Service.log_event and returns result' do
      result = described_class.log_event_sync(user:, event_name:)

      expect(result).to eq(expected_result)
      expect(UniqueUserEvents::Service).to have_received(:log_event).with(user:, event_name:)
    end

    it 'measures duration with StatsD' do
      described_class.log_event_sync(user:, event_name:)

      expect(StatsD).to have_received(:measure).with(
        'uum.unique_user_metrics.log_event.duration',
        kind_of(Numeric),
        tags: ["event_name:#{event_name}"]
      )
    end
  end

  describe '.log_event_async' do
    let(:user_id) { user.user_account_uuid }

    before do
      allow(UniqueUserEvents::EventRegistry).to receive(:validate_event!)
      allow(UniqueUserEvents::Service).to receive(:extract_user_id).and_return(user_id)
      allow(UniqueUserEvents::Buffer).to receive(:push)
      allow(StatsD).to receive(:measure)
    end

    context 'with single event' do
      before do
        allow(UniqueUserEvents::Service).to receive(:get_all_events_to_log).and_return([event_name])
        allow(UniqueUserEvents::Service).to receive(:build_buffered_result)
          .with(event_name)
          .and_return({ event_name:, status: 'buffered', new_event: false })
      end

      it 'validates the event' do
        described_class.log_event_async(user:, event_name:)

        expect(UniqueUserEvents::EventRegistry).to have_received(:validate_event!).with(event_name)
      end

      it 'extracts user_id from user' do
        described_class.log_event_async(user:, event_name:)

        expect(UniqueUserEvents::Service).to have_received(:extract_user_id).with(user)
      end

      it 'pushes event to buffer' do
        described_class.log_event_async(user:, event_name:)

        expect(UniqueUserEvents::Buffer).to have_received(:push).with(user_id:, event_name:)
      end

      it 'returns buffered result' do
        result = described_class.log_event_async(user:, event_name:)

        expect(result).to eq([{ event_name:, status: 'buffered', new_event: false }])
      end

      it 'measures async duration with StatsD' do
        described_class.log_event_async(user:, event_name:)

        expect(StatsD).to have_received(:measure).with(
          'uum.unique_user_metrics.log_event_async.duration',
          kind_of(Numeric),
          tags: ["event_name:#{event_name}"]
        )
      end
    end

    context 'with Oracle Health events' do
      let(:oh_event_name) { 'oh_984_prescriptions_accessed' }

      before do
        allow(UniqueUserEvents::Service).to receive(:get_all_events_to_log).and_return([event_name, oh_event_name])
        allow(UniqueUserEvents::Service).to receive(:build_buffered_result)
          .with(event_name)
          .and_return({ event_name:, status: 'buffered', new_event: false })
        allow(UniqueUserEvents::Service).to receive(:build_buffered_result)
          .with(oh_event_name)
          .and_return({ event_name: oh_event_name, status: 'buffered', new_event: false })
      end

      it 'pushes all events to buffer' do
        described_class.log_event_async(user:, event_name:)

        expect(UniqueUserEvents::Buffer).to have_received(:push).with(user_id:, event_name:)
        expect(UniqueUserEvents::Buffer).to have_received(:push).with(user_id:, event_name: oh_event_name)
      end

      it 'returns results for all events' do
        result = described_class.log_event_async(user:, event_name:)

        expect(result.length).to eq(2)
        expect(result).to include(
          { event_name:, status: 'buffered', new_event: false },
          { event_name: oh_event_name, status: 'buffered', new_event: false }
        )
      end
    end
  end

  describe '.log_events' do
    let(:event_name2) { UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED }

    before do
      allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_async_buffering, user).and_return(false)
      allow(UniqueUserEvents::Service).to receive(:log_event)
      allow(StatsD).to receive(:measure)
    end

    it 'logs multiple events and merges results' do
      result1 = [{ event_name:, status: 'created', new_event: true }]
      result2 = [{ event_name: event_name2, status: 'exists', new_event: false }]

      allow(UniqueUserEvents::Service).to receive(:log_event).with(user:, event_name:).and_return(result1)
      allow(UniqueUserEvents::Service).to receive(:log_event).with(user:, event_name: event_name2).and_return(result2)

      result = described_class.log_events(user:, event_names: [event_name, event_name2])

      expect(result).to eq(result1 + result2)
      expect(UniqueUserEvents::Service).to have_received(:log_event).with(user:, event_name:)
      expect(UniqueUserEvents::Service).to have_received(:log_event).with(user:, event_name: event_name2)
    end

    it 'handles empty array' do
      result = described_class.log_events(user:, event_names: [])

      expect(result).to eq([])
      expect(UniqueUserEvents::Service).not_to have_received(:log_event)
    end

    it 'handles single event' do
      result1 = [{ event_name:, status: 'created', new_event: true }]
      allow(UniqueUserEvents::Service).to receive(:log_event).and_return(result1)

      result = described_class.log_events(user:, event_names: [event_name])

      expect(result).to eq(result1)
      expect(UniqueUserEvents::Service).to have_received(:log_event).once
    end

    it 'flattens results from events that generate OH events' do
      # First event returns multiple results (original + OH events)
      result1 = [
        { event_name:, status: 'created', new_event: true },
        { event_name: 'oh_983_event', status: 'created', new_event: true }
      ]
      # Second event returns single result
      result2 = [{ event_name: event_name2, status: 'exists', new_event: false }]

      allow(UniqueUserEvents::Service).to receive(:log_event).with(user:, event_name:).and_return(result1)
      allow(UniqueUserEvents::Service).to receive(:log_event).with(user:, event_name: event_name2).and_return(result2)

      result = described_class.log_events(user:, event_names: [event_name, event_name2])

      expect(result).to eq(result1 + result2)
      expect(result.length).to eq(3)
    end
  end

  describe '.event_logged?' do
    before do
      allow(UniqueUserEvents::Service).to receive(:event_logged?)
    end

    it 'delegates to service and returns result' do
      allow(UniqueUserEvents::Service).to receive(:event_logged?).and_return(true)

      result = described_class.event_logged?(user:, event_name:)

      expect(result).to be(true)
      expect(UniqueUserEvents::Service).to have_received(:event_logged?).with(user:, event_name:)
    end

    it 'passes through service result when false' do
      allow(UniqueUserEvents::Service).to receive(:event_logged?).and_return(false)

      result = described_class.event_logged?(user:, event_name:)

      expect(result).to be(false)
      expect(UniqueUserEvents::Service).to have_received(:event_logged?).with(user:, event_name:)
    end
  end
end
