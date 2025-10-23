# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::TravelClaimNotificationCallback do
  let(:notification_id) { SecureRandom.uuid }
  let(:template_id) { 'template-123' }
  let(:uuid) { 'test-uuid-123' }
  let(:phone_last_four) { '1234' }
  let(:facility_type) { 'oh' }
  let(:callback_metadata) do
    {
      'uuid' => uuid,
      'template_id' => template_id
    }
  end

  let(:notification) do
    instance_double(
      VANotify::Notification,
      notification_id:,
      template_id:,
      status: 'delivered',
      status_reason: nil,
      callback_metadata:,
      to: "555-555-#{phone_last_four}"
    )
  end

  before do
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
  end

  describe '.call' do
    context 'when notification is delivered' do
      before do
        allow(notification).to receive(:status).and_return('delivered')
      end

      it 'increments success metrics and logs info' do
        described_class.call(notification)

        expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_DELIVERED)
        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            message: 'Travel Claim Notification SMS successfully delivered',
            notification_id:,
            template_id:,
            status: 'delivered',
            uuid:,
            phone_last_four:
          )
        )
      end
    end

    context 'when notification has permanent failure' do
      before do
        allow(notification).to receive_messages(status: 'permanent-failure', status_reason: 'Invalid phone number')
      end

      context 'with failure template for OH facility' do
        let(:template_id) { 'oh-failure-template-id' }

        it 'increments error and silent failure metrics with OH tags' do
          described_class.call(notification)

          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
          expect(StatsD).to have_received(:increment).with(
            CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
            tags: ['service:check-in', 'function: OH Travel Pay Notification Failure']
          )
        end
      end

      context 'with failure template for CIE facility' do
        let(:template_id) { 'cie-failure-template-id' }

        it 'increments error and silent failure metrics with CIE tags' do
          described_class.call(notification)

          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
          expect(StatsD).to have_received(:increment).with(
            CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
            tags: ['service:check-in', 'function: CheckIn Travel Pay Notification Failure']
          )
        end
      end

      context 'with non-failure template' do
        let(:template_id) { CheckIn::Constants::OH_SUCCESS_TEMPLATE_ID }

        it 'increments only error metrics' do
          described_class.call(notification)

          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
          expect(StatsD).not_to have_received(:increment).with(
            CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
            anything
          )
        end
      end

      it 'logs error message with details' do
        described_class.call(notification)

        expect(Rails.logger).to have_received(:error).with(
          hash_including(
            message: 'Travel Claim Notification SMS delivery permanently failed',
            notification_id:,
            template_id:,
            status: 'permanent-failure',
            status_reason: 'Invalid phone number',
            uuid:,
            phone_last_four:
          )
        )
      end
    end

    context 'when notification has temporary failure' do
      before do
        allow(notification).to receive_messages(status: 'temporary-failure', status_reason: 'Network timeout')
      end

      it 'increments error metrics and logs warning' do
        described_class.call(notification)

        expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
        expect(Rails.logger).to have_received(:warn).with(
          hash_including(
            message: 'Travel Claim Notification SMS delivery temporarily failed (end-state)',
            notification_id:,
            template_id:,
            status: 'temporary-failure',
            status_reason: 'Network timeout',
            uuid:,
            phone_last_four:
          )
        )
      end
    end

    context 'when notification has unknown status' do
      before do
        allow(notification).to receive_messages(status: 'unknown-status', status_reason: 'Unknown error')
      end

      it 'increments error metrics and logs warning' do
        described_class.call(notification)

        expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
        expect(Rails.logger).to have_received(:warn).with(
          hash_including(
            message: 'Travel Claim Notification SMS has unknown status',
            notification_id:,
            template_id:,
            status: 'unknown-status',
            status_reason: 'Unknown error',
            uuid:,
            phone_last_four:
          )
        )
      end
    end

    context 'when callback metadata is missing' do
      let(:callback_metadata) { nil }

      it 'handles missing metadata gracefully' do
        expect { described_class.call(notification) }.not_to raise_error
      end
    end

    context 'when callback metadata is empty' do
      let(:callback_metadata) { {} }

      it 'handles empty metadata gracefully' do
        expect { described_class.call(notification) }.not_to raise_error
      end
    end
  end
end
