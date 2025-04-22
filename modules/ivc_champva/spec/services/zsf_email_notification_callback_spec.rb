# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/services/ivc_champva/zsf_email_notification_callback'

RSpec.describe IvcChampva::ZsfEmailNotificationCallback do
  let(:monitor) { instance_double(IvcChampva::Monitor) }
  let(:additional_context) do
    {
      'form_id' => '10-10d',
      'form_uuid' => '12345678-1234-5678-1234-567812345678'
    }
  end
  let(:notification) do
    instance_double(
      VANotify::Notification,
      callback_metadata: {
        'additional_context' => additional_context
      },
      notification_id: 'notification-123',
      source_location: 'test_location',
      status_reason: 'test_reason'
    )
  end

  before do
    allow(IvcChampva::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive(:track_missing_status_email_sent)
    allow(monitor).to receive(:log_silent_failure_avoided)
    allow(monitor).to receive(:log_silent_failure)
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:error)
  end

  describe '.call' do
    context 'when status is delivered' do
      before do
        allow(notification).to receive(:status).and_return('delivered')
      end

      it 'increments StatsD for delivered status' do
        expect(StatsD).to receive(:increment).with('api.vanotify.notifications.delivered')
        described_class.call(notification)
      end

      it 'logs silent failure avoided' do
        expect(monitor).to receive(:log_silent_failure_avoided).with(additional_context)
        described_class.call(notification)
      end

      it 'tracks missing status email sent' do
        expect(monitor).to receive(:track_missing_status_email_sent).with('10-10d')
        described_class.call(notification)
      end
    end

    context 'when status is permanent-failure' do
      before do
        allow(notification).to receive(:status).and_return('permanent-failure')
      end

      it 'increments StatsD for permanent_failure status' do
        expect(StatsD).to receive(:increment).with('api.vanotify.notifications.permanent_failure')
        described_class.call(notification)
      end

      it 'logs an error' do
        expect(Rails.logger).to receive(:error).with(
          notification_id: 'notification-123',
          source: 'test_location',
          status: 'permanent-failure',
          status_reason: 'test_reason'
        )
        described_class.call(notification)
      end

      it 'logs silent failure' do
        expect(monitor).to receive(:log_silent_failure).with(additional_context)
        described_class.call(notification)
      end
    end

    context 'when status is temporary-failure' do
      before do
        allow(notification).to receive(:status).and_return('temporary-failure')
      end

      it 'increments StatsD for temporary_failure status' do
        expect(StatsD).to receive(:increment).with('api.vanotify.notifications.permanent_failure')
        described_class.call(notification)
      end

      it 'logs an error' do
        expect(Rails.logger).to receive(:error).with(
          notification_id: 'notification-123',
          source: 'test_location',
          status: 'temporary-failure',
          status_reason: 'test_reason'
        )
        described_class.call(notification)
      end
    end

    context 'when status is something else' do
      before do
        allow(notification).to receive(:status).and_return('unknown')
      end

      it 'increments StatsD for other status' do
        expect(StatsD).to receive(:increment).with('api.vanotify.notifications.other')
        described_class.call(notification)
      end

      it 'logs an error' do
        expect(Rails.logger).to receive(:error).with(
          notification_id: 'notification-123',
          source: 'test_location',
          status: 'unknown',
          status_reason: 'test_reason'
        )
        described_class.call(notification)
      end
    end
  end

  describe '.monitor' do
    it 'returns a new IvcChampva::Monitor instance' do
      expect(IvcChampva::Monitor).to receive(:new)
      described_class.monitor
    end
  end
end
