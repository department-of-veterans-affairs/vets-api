# frozen_string_literal: true

require 'rails_helper'

describe EventBusGateway::VANotifyEmailStatusCallback do
  describe '#call' do
    context 'notification callback' do
      let(:notification_type) { :error }
      let(:callback_metadata) { { notification_type: } }

      context 'permanent-failure' do
        let!(:notification_record) do
          build(:notification, status: 'permanent-failure', notification_id: SecureRandom.uuid, callback_metadata:)
        end

        it 'logs error and increments StatsD' do
          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:error)
          described_class.call(notification_record)
          expect(Rails.logger).to have_received(:error).with(
            'EventBusGateway::VANotifyEmailStatusCallback',
            { notification_id: notification_record.notification_id,
              source_location: notification_record.source_location,
              status: notification_record.status,
              status_reason: notification_record.status_reason,
              notification_type: notification_record.notification_type }
          )
          expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.permanent_failure')
          expect(StatsD).to have_received(:increment)
            .with('callbacks.event_bus_gateway.va_notify.notifications.permanent_failure')
        end
      end

      context 'delivered' do
        let!(:notification_record) do
          build(:notification, status: 'delivered', notification_id: SecureRandom.uuid)
        end

        it 'logs success and increments StatsD' do
          allow(StatsD).to receive(:increment)
          described_class.call(notification_record)
          expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.delivered')
          expect(StatsD).to have_received(:increment)
            .with('callbacks.event_bus_gateway.va_notify.notifications.delivered')
        end
      end

      context 'temporary-failure' do
        let!(:notification_record) do
          build(:notification, status: 'temporary-failure', notification_id: SecureRandom.uuid)
        end

        it 'logs error and increments StatsD' do
          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:error)
          described_class.call(notification_record)
          expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.temporary_failure')
          expect(StatsD).to have_received(:increment)
            .with('callbacks.event_bus_gateway.va_notify.notifications.temporary_failure')
          expect(Rails.logger).to have_received(:error).with(
            'EventBusGateway::VANotifyEmailStatusCallback',
            { notification_id: notification_record.notification_id,
              source_location: notification_record.source_location,
              status: notification_record.status,
              status_reason: notification_record.status_reason,
              notification_type: notification_record.notification_type }
          )
        end
      end

      context 'other' do
        let!(:notification_record) do
          build(:notification, status: '', notification_id: SecureRandom.uuid)
        end

        it 'logs error and increments StatsD' do
          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:error)
          described_class.call(notification_record)
          expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.other')
          StatsD.increment('callbacks.event_bus_gateway.va_notify.notifications.other')
          expect(Rails.logger).to have_received(:error).with(
            'EventBusGateway::VANotifyEmailStatusCallback',
            { notification_id: notification_record.notification_id,
              source_location: notification_record.source_location,
              status: notification_record.status,
              status_reason: notification_record.status_reason,
              notification_type: notification_record.notification_type }
          )
        end
      end
    end
  end
end
