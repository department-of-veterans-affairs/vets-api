# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events'

RSpec.describe UniqueUserEvents::Service do
  let(:user_id) { SecureRandom.uuid }
  let(:event_name) { 'test_event' }

  describe '.log_event' do
    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:debug)
      allow(Rails.logger).to receive(:error)
      allow(MHVMetricsUniqueUserEvent).to receive(:record_event)
      allow(described_class).to receive(:increment_statsd_counter)
    end

    context 'when new event is created' do
      before do
        allow(MHVMetricsUniqueUserEvent).to receive(:record_event).and_return(true)
      end

      it 'returns true and increments StatsD counter' do
        result = described_class.log_event(user_id:, event_name:)

        expect(result).to be(true)
        expect(MHVMetricsUniqueUserEvent).to have_received(:record_event).with(user_id:, event_name:)
        expect(described_class).to have_received(:increment_statsd_counter).with(event_name)
        expect(Rails.logger).to have_received(:info)
          .with('UUM: New unique event logged with metrics', { user_id:, event_name: })
      end
    end

    context 'when event already exists' do
      before do
        allow(MHVMetricsUniqueUserEvent).to receive(:record_event).and_return(false)
      end

      it 'returns false and does not increment StatsD counter' do
        result = described_class.log_event(user_id:, event_name:)

        expect(result).to be(false)
        expect(MHVMetricsUniqueUserEvent).to have_received(:record_event).with(user_id:, event_name:)
        expect(described_class).not_to have_received(:increment_statsd_counter)
        expect(Rails.logger).to have_received(:debug)
          .with('UUM: Duplicate event, no metrics increment', { user_id:, event_name: })
      end
    end

    context 'when an exception occurs' do
      let(:error_message) { 'Something went wrong' }

      before do
        allow(MHVMetricsUniqueUserEvent).to receive(:record_event).and_raise(StandardError, error_message)
      end

      it 'returns false and logs error without raising' do
        result = described_class.log_event(user_id:, event_name:)

        expect(result).to be(false)
        expect(Rails.logger).to have_received(:error)
          .with('UUM: Failed to log event', { user_id:, event_name:, error: error_message })
      end

      it 'does not increment StatsD counter when exception occurs' do
        described_class.log_event(user_id:, event_name:)

        expect(described_class).not_to have_received(:increment_statsd_counter)
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

      result = described_class.event_logged?(user_id:, event_name:)

      expect(result).to be(true)
      expect(MHVMetricsUniqueUserEvent).to have_received(:event_exists?).with(user_id:, event_name:)
    end

    it 'returns false when model returns false' do
      allow(MHVMetricsUniqueUserEvent).to receive(:event_exists?).and_return(false)

      result = described_class.event_logged?(user_id:, event_name:)

      expect(result).to be(false)
    end

    context 'when an exception occurs' do
      let(:error_message) { 'Database error' }

      before do
        allow(MHVMetricsUniqueUserEvent).to receive(:event_exists?).and_raise(StandardError, error_message)
      end

      it 'returns false and logs error without raising' do
        result = described_class.event_logged?(user_id:, event_name:)

        expect(result).to be(false)
        expect(Rails.logger).to have_received(:error)
          .with('UUM: Failed to check event', { user_id:, event_name:, error: error_message })
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

  describe 'constants' do
    it 'defines correct StatsD key prefix' do
      expect(described_class::STATSD_KEY_PREFIX).to eq('uum.unique_user_metrics')
    end
  end

  describe 'private methods' do
    it 'makes increment_statsd_counter private' do
      expect(described_class.private_methods).to include(:increment_statsd_counter)
    end
  end
end
