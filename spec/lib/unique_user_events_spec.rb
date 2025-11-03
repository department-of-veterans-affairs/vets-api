# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events'

RSpec.describe UniqueUserEvents do
  let(:user) { double('User', user_account_uuid: SecureRandom.uuid) }
  let(:event_name) { UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED }

  describe '.log_event' do
    before do
      allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(true)
      allow(UniqueUserEvents::Service).to receive(:log_event)
      allow(StatsD).to receive(:measure) # Stub StatsD calls that aren't being tested
    end

    it 'delegates to service and returns result' do
      expected_result = [{ event_name:, status: 'created', new_event: true }]
      allow(UniqueUserEvents::Service).to receive(:log_event).and_return(expected_result)

      result = described_class.log_event(user:, event_name:)

      expect(result).to eq(expected_result)
      expect(UniqueUserEvents::Service).to have_received(:log_event).with(user:, event_name:)
    end

    it 'passes through service result' do
      expected_result = [{ event_name:, status: 'exists', new_event: false }]
      allow(UniqueUserEvents::Service).to receive(:log_event).and_return(expected_result)

      result = described_class.log_event(user:, event_name:)

      expect(result).to eq(expected_result)
      expect(UniqueUserEvents::Service).to have_received(:log_event).with(user:, event_name:)
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(true)
        expected_result = [{ event_name:, status: 'created', new_event: true }]
        allow(UniqueUserEvents::Service).to receive(:log_event).and_return(expected_result)
      end

      it 'calls service and returns result' do
        expected_result = [{ event_name:, status: 'created', new_event: true }]
        result = described_class.log_event(user:, event_name:)

        expect(result).to eq(expected_result)
        expect(UniqueUserEvents::Service).to have_received(:log_event).with(user:, event_name:)
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
  end

  describe '.log_events' do
    let(:event_name2) { UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED }

    before do
      allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(true)
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

  describe 'performance metrics' do
    before do
      allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(true)
      expected_result = [{ event_name:, status: 'created', new_event: true }]
      allow(UniqueUserEvents::Service).to receive(:log_event).and_return(expected_result)
    end

    it 'measures log_event latency with StatsD' do
      expect(StatsD).to receive(:measure).with(
        'uum.unique_user_metrics.log_event.duration',
        kind_of(Numeric),
        tags: ["event_name:#{event_name}"]
      )

      described_class.log_event(user:, event_name:)
    end
  end

  describe 'error handling' do
    before do
      allow(Flipper).to receive(:enabled?).with(:unique_user_metrics_logging).and_return(true)
      allow(UniqueUserEvents::Service).to receive(:log_event).and_raise(StandardError, 'Service error')
      allow(Rails.logger).to receive(:error)
    end

    it 'returns error result when service fails' do
      result = described_class.log_event(user:, event_name:)

      expect(result).to eq([{ event_name:, status: 'error', new_event: false, error: 'Failed to process event' }])
      expect(Rails.logger).to have_received(:error)
    end
  end
end
