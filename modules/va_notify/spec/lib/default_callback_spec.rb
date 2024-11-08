# frozen_string_literal: true

require 'rails_helper'

describe VANotify::DefaultCallback do
  describe '.call' do
    context 'notification of error delivered' do
      let(:notification_record) do
        build(:notification, status: 'delivered', metadata: { notification_type: :error, statsd_tags: {} }.to_json)
      end

      it 'increments StatsD' do
        allow(StatsD).to receive(:increment)

        VANotify::DefaultCallback.call(notification_record)

        expect(StatsD).to have_received(:increment).with('silent_failure_avoided', anything)
      end
    end

    context 'notification of vbms delivered' do
      let(:notification_record) do
        build(:notification, status: 'delivered', metadata: { notification_type: :received, statsd_tags: {} }.to_json)
      end

      it 'does not increment StatsD' do
        allow(StatsD).to receive(:increment)

        VANotify::DefaultCallback.call(notification_record)

        expect(StatsD).not_to have_received(:increment)
      end
    end

    context 'notification of error permanently failed' do
      let(:notification_record) do
        build(:notification, status: 'permanent-failure',
                             metadata: { notification_type: :error, statsd_tags: {} }.to_json)
      end

      it 'increments StatsD' do
        allow(StatsD).to receive(:increment)

        VANotify::DefaultCallback.call(notification_record)

        expect(StatsD).to have_received(:increment).with('silent_failure', anything)
      end
    end

    context 'notification of vbms permanently failed' do
      let(:notification_record) do
        build(:notification, status: 'permanent-failure',
                             metadata: { notification_type: :received, statsd_tags: {} }.to_json)
      end

      it 'increments StatsD' do
        allow(StatsD).to receive(:increment)

        VANotify::DefaultCallback.call(notification_record)

        expect(StatsD).not_to have_received(:increment)
      end
    end
  end
end
