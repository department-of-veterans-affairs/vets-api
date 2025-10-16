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
