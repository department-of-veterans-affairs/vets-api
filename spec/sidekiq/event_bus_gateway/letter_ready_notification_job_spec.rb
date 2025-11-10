# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/sidekiq/event_bus_gateway/constants'
require_relative 'shared_examples_letter_ready_job'

RSpec.describe EventBusGateway::LetterReadyNotificationJob, type: :job do
  subject { described_class }

  let(:participant_id) { '1234' }
  let(:email_template_id) { '5678' }
  let(:push_template_id) { '9012' }

  let(:bgs_profile) do
    {
      first_nm: 'Joe',
      last_nm: 'Smith',
      brthdy_dt: 30.years.ago,
      ssn_nbr: '123456789'
    }
  end

  let(:mpi_profile) { build(:mpi_profile) }
  let(:mpi_profile_response) { create(:find_profile_response, profile: mpi_profile) }

  let(:notification_id) { SecureRandom.uuid }
  let(:va_notify_service) do
    service = instance_double(VaNotify::Service)
    email_response = instance_double(Notifications::Client::ResponseNotification, id: notification_id)
    push_response = double(id: notification_id)

    allow(service).to receive_messages(send_email: email_response, send_push: push_response)
    service
  end

  let(:user_account) { create(:user_account, icn: mpi_profile_response.profile.icn) }

  before do
    # Ensure we have clean test state and proper mocking
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
    allow(StatsD).to receive(:increment)
  end

  describe '#perform' do
    context 'when participant data is valid' do
      before do
        user_account
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        allow_any_instance_of(BGS::PersonWebService)
          .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)
        allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
      end

      context 'with both email and push template IDs' do
        it 'sends both notifications and increments success metrics' do
          Sidekiq::Testing.inline! do
            expect(va_notify_service).to receive(:send_email).with({
                                                                     recipient_identifier: { id_value: participant_id,
                                                                                             id_type: 'PID' },
                                                                     template_id: email_template_id,
                                                                     personalisation: { host: Settings.hostname,
                                                                                        first_name: 'Joe' }
                                                                   }).and_return(double(id: notification_id))

            expect(va_notify_service).to receive(:send_push).with({
                                                                    mobile_app: 'VA_FLAGSHIP_APP',
                                                                    recipient_identifier: {
                                                                      id_value: mpi_profile_response.profile.icn, id_type: 'ICN'
                                                                    },
                                                                    template_id: push_template_id,
                                                                    personalisation: {}
                                                                  }).and_return(double(id: notification_id))

            expect(StatsD).to receive(:increment)
              .with('event_bus_gateway.letter_ready_email.success', tags: EventBusGateway::Constants::DD_TAGS)
            expect(StatsD).to receive(:increment)
              .with('event_bus_gateway.letter_ready_push.success', tags: EventBusGateway::Constants::DD_TAGS)

            expect do
              subject.new.perform(participant_id, email_template_id, push_template_id)
            end.to change(EventBusGatewayNotification, :count).by(1)
               .and change(EventBusGatewayPushNotification, :count).by(1)
          end
        end
      end

      context 'with only email template ID' do
        it 'sends only email notification and increments success metrics' do
          Sidekiq::Testing.inline! do
            expect(va_notify_service).to receive(:send_email).and_return(double(id: notification_id))
            expect(va_notify_service).not_to receive(:send_push)

            expect(StatsD).to receive(:increment)
              .with('event_bus_gateway.letter_ready_email.success', tags: EventBusGateway::Constants::DD_TAGS)

            expect do
              subject.new.perform(participant_id, email_template_id)
            end.to change(EventBusGatewayNotification, :count).by(1)
                .and not_change(EventBusGatewayPushNotification, :count)
          end
        end
      end

      context 'with only push notification template ID' do
        it 'sends only push notification and increments success metrics' do
          Sidekiq::Testing.inline! do
            expect(va_notify_service).not_to receive(:send_email)
            expect(va_notify_service).to receive(:send_push)

            expect(StatsD).to receive(:increment)
                                .with('event_bus_gateway.letter_ready_push.success', tags: EventBusGateway::Constants::DD_TAGS)

            expect do
              subject.new.perform(participant_id, nil, push_template_id)
            end.to not_change(EventBusGatewayNotification, :count)
                                                              .and change(EventBusGatewayPushNotification, :count).by(1)
        end
      end


      context 'when ICN is not available' do
        let(:mpi_profile_no_icn) { build(:mpi_profile, icn: nil) }
        let(:mpi_profile_response_no_icn) { create(:find_profile_response, profile: mpi_profile_no_icn) }

        before do
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
            .and_return(mpi_profile_response_no_icn)
        end

        it 'does not send push notification or email' do
          expect(va_notify_service).not_to receive(:send_email)
          expect(va_notify_service).not_to receive(:send_push)

          subject.new.perform(participant_id, email_template_id, push_template_id)
        end
      end
    end

      context 'when email job fails but push job succeeds' do
        it 'sends push notification and increments appropriate metrics' do
          Sidekiq::Testing.inline! do
            allow(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async)
              .and_raise(StandardError, 'Email job failed')
            allow(va_notify_service).to receive(:send_push)

            result = subject.new.perform(participant_id, email_template_id, push_template_id)
            
            expect(result).to eq([{ type: 'email', error: 'Email job failed' }])
            expect do
              subject.new.perform(participant_id, email_template_id, push_template_id)
            end.to not_change(EventBusGatewayNotification, :count)
                .and change(EventBusGatewayPushNotification, :count).by(1)
          end
        end
      end

      context 'when push job fails but email job succeeds' do
        it 'sends email notification and increments appropriate metrics' do
          Sidekiq::Testing.inline! do
            allow(va_notify_service).to receive(:send_email).and_return(double(id: notification_id))
            allow(EventBusGateway::LetterReadyPushJob).to receive(:perform_async)
              .and_raise(StandardError, 'Push job failed')

            expect(StatsD).to receive(:increment)
              .with('event_bus_gateway.letter_ready_email.success', tags: EventBusGateway::Constants::DD_TAGS)

            result = subject.new.perform(participant_id, email_template_id, push_template_id)
            expect(result).to eq([{ type: 'push', error: 'Push job failed' }])
            expect do
              subject.new.perform(participant_id, email_template_id, push_template_id)
            end.to change(EventBusGatewayNotification, :count).by(1)
                .and not_change(EventBusGatewayPushNotification, :count)
          end
        end
      end

      context 'when both email and push jobs fail' do
        it 'raises an error' do
          Sidekiq::Testing.inline! do
            allow(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async)
              .and_raise(StandardError, 'Email job failed')
            allow(EventBusGateway::LetterReadyPushJob).to receive(:perform_async)
              .and_raise(StandardError, 'Push job failed')

            expect do
              subject.new.perform(participant_id, email_template_id, push_template_id)
            end.to raise_error(StandardError)
              .and not_change(EventBusGatewayNotification, :count)
              .and not_change(EventBusGatewayPushNotification, :count)
          end
        end
      end

      context 'when BGS error occurs' do
        include_examples 'letter ready job bgs error handling', 'Notification'

        it 'does not send any notifications and records failure' do
          expect(va_notify_service).not_to receive(:send_email)
          expect(va_notify_service).not_to receive(:send_push)
          
          # Should record failure for BGS lookup errors
          expect_any_instance_of(described_class).to receive(:record_notification_send_failure)

          expect do
            subject.new.perform(participant_id, email_template_id, push_template_id)
          end.to raise_error(StandardError, 'Participant ID cannot be found in BGS')
        end
      end

      context 'when MPI error occurs' do
        include_examples 'letter ready job mpi error handling', 'Notification'

        it 'does not send any notifications and records failure' do
          expect(va_notify_service).not_to receive(:send_email)
          expect(va_notify_service).not_to receive(:send_push)
          
          # Should record failure for MPI lookup errors
          expect_any_instance_of(described_class).to receive(:record_notification_send_failure)

          expect do
            subject.new.perform(participant_id, email_template_id, push_template_id)
          end.to raise_error(RuntimeError, 'Failed to fetch MPI profile')
        end
      end
    end
  end

  include_examples 'letter ready job sidekiq retries exhausted', 'Notification'
end
