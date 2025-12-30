# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/attr_package'
require_relative '../../../app/sidekiq/event_bus_gateway/constants'
require_relative 'shared_examples_letter_ready_job'

RSpec.describe EventBusGateway::LetterReadyNotificationJob, type: :job do
  subject { described_class }

  # Shared setup for most test scenarios
  before do
    allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
      .and_return(mpi_profile_response)
    allow_any_instance_of(BGS::PersonWebService)
      .to receive(:find_person_by_ptcpnt_id)
      .and_return(bgs_profile)
    allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
    allow(Sidekiq::AttrPackage).to receive(:create).and_return('test_cache_key_123')
    allow(Sidekiq::AttrPackage).to receive(:delete)
    allow(Flipper).to receive(:enabled?)
      .with(:event_bus_gateway_letter_ready_push_notifications, instance_of(Flipper::Actor))
      .and_return(true)
  end

  let(:participant_id) { '1234' }
  let(:email_template_id) { '5678' }
  let(:push_template_id) { '9012' }
  let(:notification_id) { SecureRandom.uuid }

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
  let!(:user_account) { create(:user_account, icn: mpi_profile_response.profile.icn) }

  let(:va_notify_service) do
    instance_double(VaNotify::Service).tap do |service|
      email_response = instance_double(Notifications::Client::ResponseNotification, id: notification_id)
      push_response = double(id: notification_id)
      allow(service).to receive_messages(send_email: email_response, send_push: push_response)
    end
  end

  let(:expected_email_args) do
    {
      recipient_identifier: { id_value: participant_id, id_type: 'PID' },
      template_id: email_template_id,
      personalisation: { host: Settings.hostname, first_name: 'Joe' }
    }
  end

  let(:expected_push_args) do
    {
      mobile_app: 'VA_FLAGSHIP_APP',
      recipient_identifier: { id_value: mpi_profile_response.profile.icn, id_type: 'ICN' },
      template_id: push_template_id,
      personalisation: {}
    }
  end

  describe '#perform' do
    describe 'successful notification sending' do
      around do |example|
        Sidekiq::Testing.inline! { example.run }
      end

      context 'with both email and push template IDs' do
        it 'sends both notifications with correct arguments' do
          expect(va_notify_service).to receive(:send_email).with(expected_email_args)
          expect(va_notify_service).to receive(:send_push).with(expected_push_args)

          result = subject.new.perform(participant_id, email_template_id, push_template_id)
          expect(result).to eq([])
        end

        it 'creates both notification records' do
          expect do
            subject.new.perform(participant_id, email_template_id, push_template_id)
          end.to change(EventBusGatewayNotification, :count).by(1)
                                                            .and change(EventBusGatewayPushNotification, :count).by(1)
        end

        it 'increments success metrics for both notification types' do
          expect(StatsD).to receive(:increment).with(
            'event_bus_gateway.letter_ready_email.success',
            tags: EventBusGateway::Constants::DD_TAGS
          )
          expect(StatsD).to receive(:increment).with(
            'event_bus_gateway.letter_ready_push.success',
            tags: EventBusGateway::Constants::DD_TAGS
          )

          subject.new.perform(participant_id, email_template_id, push_template_id)
        end
      end

      context 'with only email template ID' do
        it 'sends only email notification' do
          expect(va_notify_service).to receive(:send_email)
          expect(va_notify_service).not_to receive(:send_push)

          result = subject.new.perform(participant_id, email_template_id)
          expect(result).to eq([])
        end

        it 'creates only email notification record' do
          expect do
            subject.new.perform(participant_id, email_template_id)
          end.to change(EventBusGatewayNotification, :count).by(1)
                                                            .and not_change(EventBusGatewayPushNotification, :count)
        end

        it 'increments email success metric and push skipped metric' do
          expect(StatsD).to receive(:increment).with(
            'event_bus_gateway.letter_ready_email.success',
            tags: EventBusGateway::Constants::DD_TAGS
          )
          expect(StatsD).to receive(:increment).with(
            'event_bus_gateway.letter_ready_notification.skipped',
            tags: EventBusGateway::Constants::DD_TAGS + ['notification_type:push',
                                                         'reason:icn_or_template_not_available']
          )

          subject.new.perform(participant_id, email_template_id)
        end
      end

      context 'PII protection with AttrPackage' do
        it 'stores PII in Redis and passes only cache_key to email job' do
          expect(Sidekiq::AttrPackage).to receive(:create).with(
            first_name: 'Joe',
            icn: mpi_profile_response.profile.icn
          ).and_return('email_cache_key')

          expect(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async).with(
            participant_id,
            email_template_id,
            'email_cache_key'
          )

          subject.new.perform(participant_id, email_template_id, push_template_id)
        end

        it 'stores PII in Redis and passes only cache_key to push job' do
          expect(Sidekiq::AttrPackage).to receive(:create).with(
            icn: mpi_profile_response.profile.icn
          ).and_return('push_cache_key')

          expect(EventBusGateway::LetterReadyPushJob).to receive(:perform_async).with(
            participant_id,
            push_template_id,
            'push_cache_key'
          )

          subject.new.perform(participant_id, email_template_id, push_template_id)
        end
      end

      context 'with only push template ID' do
        it 'sends only push notification' do
          expect(va_notify_service).not_to receive(:send_email)
          expect(va_notify_service).to receive(:send_push)

          result = subject.new.perform(participant_id, nil, push_template_id)
          expect(result).to eq([])
        end

        it 'creates only push notification record' do
          expect do
            subject.new.perform(participant_id, nil, push_template_id)
          end.to not_change(EventBusGatewayNotification, :count)
            .and change(EventBusGatewayPushNotification, :count).by(1)
        end

        it 'increments push success metric and email skipped metric' do
          expect(StatsD).to receive(:increment).with(
            'event_bus_gateway.letter_ready_push.success',
            tags: EventBusGateway::Constants::DD_TAGS
          )
          expect(StatsD).to receive(:increment).with(
            'event_bus_gateway.letter_ready_notification.skipped',
            tags: EventBusGateway::Constants::DD_TAGS + ['notification_type:email',
                                                         'reason:icn_or_template_not_available']
          )

          subject.new.perform(participant_id, nil, push_template_id)
        end
      end

      it 'configures sidekiq retry count' do
        expect(described_class.get_sidekiq_options['retry']).to eq(EventBusGateway::Constants::SIDEKIQ_RETRY_COUNT_FIRST_NOTIFICATION)
      end
    end

    describe 'data validation scenarios' do
      around do |example|
        Sidekiq::Testing.inline! { example.run }
      end

      context 'when ICN is not available' do
        let(:mpi_profile) { build(:mpi_profile, icn: nil) }

        it 'does not send any notifications and returns empty array' do
          expect(va_notify_service).not_to receive(:send_email)
          expect(va_notify_service).not_to receive(:send_push)

          result = subject.new.perform(participant_id, email_template_id, push_template_id)
          expect(result).to eq([])
        end

        it 'logs skipped notifications for both email and push' do
          expect(Rails.logger).to receive(:error).with(
            'LetterReadyNotificationJob email skipped',
            {
              notification_type: 'email',
              reason: 'ICN or template not available',
              template_id: email_template_id
            }
          )
          expect(Rails.logger).to receive(:error).with(
            'LetterReadyNotificationJob push skipped',
            {
              notification_type: 'push',
              reason: 'ICN or template not available',
              template_id: push_template_id
            }
          )

          subject.new.perform(participant_id, email_template_id, push_template_id)
        end

        it 'increments skipped metrics for both email and push' do
          expect(StatsD).to receive(:increment).with(
            'event_bus_gateway.letter_ready_notification.skipped',
            tags: EventBusGateway::Constants::DD_TAGS + ['notification_type:email',
                                                         'reason:icn_or_template_not_available']
          )
          expect(StatsD).to receive(:increment).with(
            'event_bus_gateway.letter_ready_notification.skipped',
            tags: EventBusGateway::Constants::DD_TAGS + ['notification_type:push',
                                                         'reason:icn_or_template_not_available']
          )

          subject.new.perform(participant_id, email_template_id, push_template_id)
        end
      end

      context 'when BGS person name is missing' do
        let(:bgs_profile) { { last_nm: 'Smith', ssn_nbr: '123456789' } }

        it 'skips email but still sends push notification' do
          expect(va_notify_service).not_to receive(:send_email)
          expect(va_notify_service).to receive(:send_push)

          expect(StatsD).to receive(:increment).with(
            'event_bus_gateway.letter_ready_push.success',
            tags: EventBusGateway::Constants::DD_TAGS
          )

          result = subject.new.perform(participant_id, email_template_id, push_template_id)
          expect(result).to eq([])
        end

        it 'creates only push notification record' do
          expect do
            subject.new.perform(participant_id, email_template_id, push_template_id)
          end.to not_change(EventBusGatewayNotification, :count)
            .and change(EventBusGatewayPushNotification, :count).by(1)
        end

        it 'logs skipped email notification due to missing first_name' do
          expect(Rails.logger).to receive(:error).with(
            'LetterReadyNotificationJob email skipped',
            {
              notification_type: 'email',
              reason: 'first_name not present',
              template_id: email_template_id
            }
          )

          subject.new.perform(participant_id, email_template_id, push_template_id)
        end

        it 'increments skipped metric for email' do
          expect(StatsD).to receive(:increment).with(
            'event_bus_gateway.letter_ready_notification.skipped',
            tags: EventBusGateway::Constants::DD_TAGS + ['notification_type:email', 'reason:first_name_not_present']
          )

          subject.new.perform(participant_id, email_template_id, push_template_id)
        end
      end
    end

    describe 'partial failure scenarios' do
      around do |example|
        Sidekiq::Testing.inline! { example.run }
      end

      context 'when email job fails but push job succeeds' do
        before do
          allow(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async)
            .and_raise(StandardError, 'Email job failed')
        end

        it 'sends push notification and returns error for email' do
          expect(va_notify_service).to receive(:send_push)
          expect(Rails.logger).to receive(:warn).with(
            'LetterReadyNotificationJob partial failure',
            {
              successful: 'push',
              failed: 'email: Email job failed'
            }
          )

          result = subject.new.perform(participant_id, email_template_id, push_template_id)
          expect(result).to eq([{ type: 'email', error: 'Email job failed' }])
        end

        it 'creates only push notification record' do
          expect do
            subject.new.perform(participant_id, email_template_id, push_template_id)
          end.to not_change(EventBusGatewayNotification, :count)
            .and change(EventBusGatewayPushNotification, :count).by(1)
        end
      end

      context 'when push job fails but email job succeeds' do
        before do
          allow(EventBusGateway::LetterReadyPushJob).to receive(:perform_async)
            .and_raise(StandardError, 'Push job failed')
        end

        it 'sends email notification and returns error for push' do
          expect(va_notify_service).to receive(:send_email)
          expect(Rails.logger).to receive(:warn).with(
            'LetterReadyNotificationJob partial failure',
            {
              successful: 'email',
              failed: 'push: Push job failed'
            }
          )

          expect(StatsD).to receive(:increment).with(
            'event_bus_gateway.letter_ready_email.success',
            tags: EventBusGateway::Constants::DD_TAGS
          )

          result = subject.new.perform(participant_id, email_template_id, push_template_id)
          expect(result).to eq([{ type: 'push', error: 'Push job failed' }])
        end

        it 'creates only email notification record' do
          expect do
            subject.new.perform(participant_id, email_template_id, push_template_id)
          end.to change(EventBusGatewayNotification, :count).by(1)
                                                            .and not_change(EventBusGatewayPushNotification, :count)
        end
      end

      context 'when both email and push jobs fail' do
        before do
          allow(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async)
            .and_raise(StandardError, 'Email job failed')
          allow(EventBusGateway::LetterReadyPushJob).to receive(:perform_async)
            .and_raise(StandardError, 'Push job failed')
        end

        it 'raises error with combined failure message' do
          expect do
            subject.new.perform(participant_id, email_template_id, push_template_id)
          end.to raise_error(EventBusGateway::Errors::NotificationEnqueueError, /All notifications failed/)
            .and not_change(EventBusGatewayNotification, :count)
            .and not_change(EventBusGatewayPushNotification, :count)
        end
      end
    end

    describe 'error handling' do
      context 'when BGS service fails' do
        include_examples 'letter ready job bgs error handling', 'Notification'

        it 'does not send any notifications and records failure' do
          expect(va_notify_service).not_to receive(:send_email)
          expect(va_notify_service).not_to receive(:send_push)
          expect_any_instance_of(described_class).to receive(:record_notification_send_failure)

          expect do
            subject.new.perform(participant_id, email_template_id, push_template_id)
          end.to raise_error(EventBusGateway::Errors::BgsPersonNotFoundError, 'Participant ID cannot be found in BGS')
        end
      end

      context 'when MPI service fails' do
        include_examples 'letter ready job mpi error handling', 'Notification'

        it 'does not send any notifications and records failure' do
          expect(va_notify_service).not_to receive(:send_email)
          expect(va_notify_service).not_to receive(:send_push)
          expect_any_instance_of(described_class).to receive(:record_notification_send_failure)

          expect do
            subject.new.perform(participant_id, email_template_id, push_template_id)
          end.to raise_error(EventBusGateway::Errors::MpiProfileNotFoundError, 'Failed to fetch MPI profile')
        end
      end

      context 'when an unexpected error occurs during data fetching' do
        before do
          allow_any_instance_of(BGS::PersonWebService)
            .to receive(:find_person_by_ptcpnt_id)
            .and_raise(StandardError, 'Unexpected BGS error')
        end

        it 'records failure because instance variables are nil' do
          expect_any_instance_of(described_class).to receive(:record_notification_send_failure)
            .with(instance_of(StandardError), 'Notification')

          expect do
            subject.new.perform(participant_id, email_template_id, push_template_id)
          end.to raise_error(StandardError, 'Unexpected BGS error')
        end
      end

      context 'when error occurs after data fetching completes' do
        before do
          allow(EventBusGateway::LetterReadyEmailJob).to receive(:perform_async)
            .and_raise(StandardError, 'Email job enqueue failed')
        end

        it 'does not record notification send failure' do
          expect_any_instance_of(described_class).not_to receive(:record_notification_send_failure)

          expect do
            subject.new.perform(participant_id, email_template_id, push_template_id)
          end.not_to raise_error
        end

        it 'returns error in the errors array' do
          result = subject.new.perform(participant_id, email_template_id, push_template_id)
          expect(result).to eq([{ type: 'email', error: 'Email job enqueue failed' }])
        end
      end
    end

    describe 'feature flag scenarios' do
      around do |example|
        Sidekiq::Testing.inline! { example.run }
      end

      context 'when push notifications feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:event_bus_gateway_letter_ready_push_notifications, instance_of(Flipper::Actor))
            .and_return(false)
        end

        it 'sends email but skips push notification' do
          expect(va_notify_service).to receive(:send_email)
          expect(va_notify_service).not_to receive(:send_push)

          subject.new.perform(participant_id, email_template_id, push_template_id)
        end

        it 'logs that push notification was skipped due to feature flag' do
          expect(Rails.logger).to receive(:error).with(
            'LetterReadyNotificationJob push skipped',
            {
              notification_type: 'push',
              reason: 'Push notifications not enabled for this user',
              template_id: push_template_id
            }
          )

          subject.new.perform(participant_id, email_template_id, push_template_id)
        end

        it 'increments skipped metric for push with feature flag reason' do
          expect(StatsD).to receive(:increment).with(
            'event_bus_gateway.letter_ready_email.success',
            tags: EventBusGateway::Constants::DD_TAGS
          )
          expect(StatsD).to receive(:increment).with(
            'event_bus_gateway.letter_ready_notification.skipped',
            tags: EventBusGateway::Constants::DD_TAGS + ['notification_type:push',
                                                         'reason:push_notifications_not_enabled_for_this_user']
          )

          subject.new.perform(participant_id, email_template_id, push_template_id)
        end
      end

      context 'when push notifications feature flag is enabled' do
        it 'sends both email and push notifications' do
          expect(va_notify_service).to receive(:send_email)
          expect(va_notify_service).to receive(:send_push)

          subject.new.perform(participant_id, email_template_id, push_template_id)
        end
      end
    end
  end

  include_examples 'letter ready job sidekiq retries exhausted', 'Notification'
end
