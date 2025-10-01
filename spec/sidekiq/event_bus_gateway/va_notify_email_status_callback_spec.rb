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
          expect(StatsD).to have_received(:increment)
            .with("#{described_class::STATSD_METRIC_PREFIX}.va_notify.notifications.permanent-failure", tags: EventBusGateway::Constants::DD_TAGS)
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
          expect(StatsD).to have_received(:increment)
            .with("#{described_class::STATSD_METRIC_PREFIX}.va_notify.notifications.delivered", tags: EventBusGateway::Constants::DD_TAGS)
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
            expect(EventBusGateway::LetterReadyRetryEmailJob).not_to receive(:perform_in)
            described_class.call(notification_record)
          end

          it 'logs error and increments StatsD' do
            allow(StatsD).to receive(:increment)
            allow(Rails.logger).to receive(:error)
            described_class.call(notification_record)
            expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.temporary_failure')
            expect(StatsD).to have_received(:increment)
              .with('callbacks.event_bus_gateway.va_notify.notifications.temporary_failure')
            expect(StatsD).to have_received(:increment)
              .with("#{described_class::STATSD_METRIC_PREFIX}.va_notify.notifications.temporary-failure", tags: EventBusGateway::Constants::DD_TAGS)
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
          let(:ebg_noti) do
            create(:event_bus_gateway_notification, user_account:, va_notify_id: notification_record.notification_id)
          end

          before do
            allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_retry_emails).and_return(true)
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(mpi_profile_response)
            ebg_noti
          end

          it 'attempts to send the email again using LetterReadyRetryEmailJob' do
            expected_personalisation = {
              host: EventBusGateway::Constants::HOSTNAME_MAPPING[Settings.hostname] || Settings.hostname,
              first_name: mpi_profile.given_names.first
            }
            expect(EventBusGateway::LetterReadyRetryEmailJob).to receive(:perform_in).with(
              1.hour,
              mpi_profile.participant_id,
              ebg_noti.template_id,
              expected_personalisation,
              ebg_noti.id
            )
            described_class.call(notification_record)
          end

          it 'increments queued retry success metric' do
            allow(EventBusGateway::LetterReadyRetryEmailJob).to receive(:perform_in)
            allow(StatsD).to receive(:increment)
            described_class.call(notification_record)
            expect(StatsD).to have_received(:increment)
              .with("#{described_class::STATSD_METRIC_PREFIX}.queued_retry_success",
                    tags: EventBusGateway::Constants::DD_TAGS)
          end

          it 'logs error and increments StatsD' do
            allow(EventBusGateway::LetterReadyRetryEmailJob).to receive(:perform_in)
            allow(StatsD).to receive(:increment)
            allow(Rails.logger).to receive(:error)
            described_class.call(notification_record)
            expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.temporary_failure')
            expect(StatsD).to have_received(:increment)
              .with('callbacks.event_bus_gateway.va_notify.notifications.temporary_failure')
            expect(StatsD).to have_received(:increment)
              .with("#{described_class::STATSD_METRIC_PREFIX}.va_notify.notifications.temporary-failure", tags: EventBusGateway::Constants::DD_TAGS)
            expect(Rails.logger).to have_received(:error).with(
              'EventBusGateway::VANotifyEmailStatusCallback',
              { notification_id: notification_record.notification_id,
                source_location: notification_record.source_location,
                status: notification_record.status,
                status_reason: notification_record.status_reason,
                notification_type: notification_record.notification_type }
            )
          end

          context 'when max attempts exceeded' do
            before do
              ebg_noti.update!(attempts: EventBusGateway::Constants::MAX_EMAIL_ATTEMPTS + 1)
            end

            it 'does not queue retry job and logs exhausted retries' do
              allow(Rails.logger).to receive(:error)
              allow(StatsD).to receive(:increment)

              expect(EventBusGateway::LetterReadyRetryEmailJob).not_to receive(:perform_in)

              # Expect the standard error log for temporary-failure
              expect(Rails.logger).to receive(:error).with(
                'EventBusGateway::VANotifyEmailStatusCallback',
                { notification_id: notification_record.notification_id,
                  source_location: notification_record.source_location,
                  status: notification_record.status,
                  status_reason: notification_record.status_reason,
                  notification_type: notification_record.notification_type }
              )

              # Expect the exhausted retry log with simplified fields
              expect(Rails.logger).to receive(:error).with(
                'EventBusGateway email retries exhausted',
                { ebg_notification_id: ebg_noti.id,
                  max_attempts: EventBusGateway::Constants::MAX_EMAIL_ATTEMPTS }
              )

              expect(StatsD).to receive(:increment)
                .with("#{described_class::STATSD_METRIC_PREFIX}.exhausted_retries",
                      tags: EventBusGateway::Constants::DD_TAGS)

              described_class.call(notification_record)
            end
          end

          context 'when EventBusGatewayNotification is not found' do
            before do
              allow(EventBusGatewayNotification).to receive(:find_by).and_return(nil)
              allow(StatsD).to receive(:increment)
            end

            it 'raises EventBusGatewayNotificationNotFoundError and increments failure metric' do
              expect(StatsD).to receive(:increment)
                .with("#{described_class::STATSD_METRIC_PREFIX}.queued_retry_failure",
                      tags: EventBusGateway::Constants::DD_TAGS + ['function: EventBusGateway::VANotifyEmailStatusCallback::EventBusGatewayNotificationNotFoundError'])

              expect { described_class.call(notification_record) }
                .to raise_error(EventBusGateway::VANotifyEmailStatusCallback::EventBusGatewayNotificationNotFoundError)
            end
          end

          context 'when MPI lookup fails' do
            before do
              mpi_error_response = instance_double(MPI::Responses::FindProfileResponse, ok?: false)
              allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(mpi_error_response)
              allow(StatsD).to receive(:increment)
            end

            it 'raises MPIError and increments failure metric' do
              expect(StatsD).to receive(:increment)
                .with("#{described_class::STATSD_METRIC_PREFIX}.queued_retry_failure",
                      tags: EventBusGateway::Constants::DD_TAGS + ['function: EventBusGateway::VANotifyEmailStatusCallback::MPIError'])

              expect { described_class.call(notification_record) }
                .to raise_error(EventBusGateway::VANotifyEmailStatusCallback::MPIError)
            end
          end

          context 'when first name is missing' do
            before do
              profile_without_name = build(:mpi_profile, given_names: nil)
              mpi_response = create(:find_profile_response, profile: profile_without_name)
              allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(mpi_response)
              allow(StatsD).to receive(:increment)
            end

            it 'raises MPINameError and increments failure metric' do
              expect(StatsD).to receive(:increment)
                .with("#{described_class::STATSD_METRIC_PREFIX}.queued_retry_failure",
                      tags: EventBusGateway::Constants::DD_TAGS + ['function: EventBusGateway::VANotifyEmailStatusCallback::MPINameError'])

              expect { described_class.call(notification_record) }
                .to raise_error(EventBusGateway::VANotifyEmailStatusCallback::MPINameError)
            end
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
          expect(StatsD).to have_received(:increment)
            .with('callbacks.event_bus_gateway.va_notify.notifications.other')
          expect(StatsD).to have_received(:increment)
            .with("#{described_class::STATSD_METRIC_PREFIX}.va_notify.notifications.", tags: EventBusGateway::Constants::DD_TAGS)
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
