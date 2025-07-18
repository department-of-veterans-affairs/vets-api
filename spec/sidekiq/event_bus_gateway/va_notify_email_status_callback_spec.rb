# frozen_string_literal: true

require 'rails_helper'

describe EventBusGateway::VANotifyEmailStatusCallback do
  describe '#call' do
    context 'notification callback' do
      let(:notification_type) { :error }
      let(:callback_metadata) { { notification_type: } }

      context 'permanent-failure' do
        let!(:notification_record) do
          build(:notification, id: SecureRandom.uuid, status: 'permanent-failure', notification_id: SecureRandom.uuid,
                               callback_metadata:)
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
          build(:notification, id: SecureRandom.uuid, status: 'delivered', notification_id: SecureRandom.uuid)
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
          build(:notification, id: SecureRandom.uuid, status: 'temporary-failure', notification_id: SecureRandom.uuid)
        end

        context 'when event_bus_gateway_retry_emails is disabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_retry_emails).and_return(false)
          end

          it 'does not attempt to send the email again' do
            expect(EventBusGateway::LetterReadyEmailJob).not_to receive(:perform_async)
            described_class.call(notification_record)
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

        context 'when event_bus_gateway_retry_emails is enabled' do
          let(:mpi_profile) { build(:mpi_profile) }
          let(:mpi_profile_response) { create(:find_profile_response, profile: mpi_profile) }
          let(:user_account) { create(:user_account, icn: mpi_profile_response.profile.icn) }
          let(:template_id) { '5678' }
          let(:ebg_noti) do
            create(:event_bus_gateway_notification, user_account:, va_notify_id: notification_record.id)
          end

          before do
            allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_retry_emails).and_return(true)
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(mpi_profile_response)
            ebg_noti
          end

          it 'attempts to send the email again' do
            expect(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async)
            described_class.call(notification_record)
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
      end

      context 'other' do
        let!(:notification_record) do
          build(:notification, id: SecureRandom.uuid, status: '', notification_id: SecureRandom.uuid)
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
