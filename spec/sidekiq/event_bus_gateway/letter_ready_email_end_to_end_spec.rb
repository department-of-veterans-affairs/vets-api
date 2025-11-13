# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/service'

RSpec.describe 'EventBusGateway Letter Ready Email End-to-End Flow', type: :feature do
  let(:participant_id) { '1234567890' }
  let(:template_id) { '5678' }
  let(:initial_va_notify_id) { SecureRandom.uuid }
  let(:retry_va_notify_id) { SecureRandom.uuid }
  let(:retry_va_notify_id_second) { SecureRandom.uuid }

  # Test data setup
  let(:bgs_profile) do
    {
      first_nm: 'John',
      last_nm: 'Smith',
      brthdy_dt: 30.years.ago,
      ssn_nbr: '123456789'
    }
  end

  let(:mpi_profile) { build(:mpi_profile, participant_id:) }
  let(:mpi_profile_response) { create(:find_profile_response, profile: mpi_profile) }
  let(:user_account) { create(:user_account, icn: mpi_profile_response.profile.icn) }

  # Mock services
  let(:va_notify_service) { instance_double(VaNotify::Service) }

  before do
    # Clear any existing jobs
    Sidekiq::Worker.clear_all

    # Setup user account
    user_account

    # Mock external services
    allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
    allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
      .and_return(mpi_profile_response)
    allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier)
      .and_return(mpi_profile_response)
    allow_any_instance_of(BGS::PersonWebService)
      .to receive(:find_person_by_ptcpnt_id).and_return(bgs_profile)

    # Mock StatsD and Rails logger
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:info)
  end

  # Helper method to create notification doubles
  def create_notification_double(va_notify_id, status, options = {})
    double('notification',
           id: options[:id] || SecureRandom.random_number(1_000_000),
           status:,
           notification_id: va_notify_id,
           source_location: options[:source_location] || 'test',
           status_reason: options[:status_reason] || "test #{status}",
           notification_type: options[:notification_type] || 'email')
  end

  describe 'Successful email flow without retries' do
    it 'completes the full flow: controller -> job -> email sent -> delivered callback' do
      # Mock successful email send
      email_response = instance_double(Notifications::Client::ResponseNotification, id: initial_va_notify_id)
      expect(va_notify_service).to receive(:send_email).once.and_return(email_response)

      # Step 1: Simulate controller request
      EventBusGateway::LetterReadyEmailJob.perform_async(participant_id, template_id)

      # Step 2: Process the job
      expect do
        Sidekiq::Worker.drain_all
      end.to change(EventBusGatewayNotification, :count).by(1)

      # Verify notification was created
      notification = EventBusGatewayNotification.last
      expect(notification.user_account).to eq(user_account)
      expect(notification.template_id).to eq(template_id)
      expect(notification.va_notify_id).to eq(initial_va_notify_id)
      expect(notification.attempts).to eq(1)

      # Step 3: Simulate delivered callback
      delivered_notification = create_notification_double(initial_va_notify_id, 'delivered',
                                                          status_reason: 'delivered')
      EventBusGateway::VANotifyEmailStatusCallback.call(delivered_notification)

      # Verify metrics were recorded for delivery
      expect(StatsD).to have_received(:increment)
        .with('callbacks.event_bus_gateway.va_notify.notifications.delivered')

      # Verify no retry jobs were queued
      expect(EventBusGateway::LetterReadyRetryEmailJob.jobs).to be_empty
    end
  end

  describe 'Email retry flows with event_bus_gateway_retry_emails enabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_retry_emails).and_return(true)
    end

    it "Allow up to #{EventBusGateway::Constants::MAX_EMAIL_ATTEMPTS} attempts." do
      initial_response = instance_double(Notifications::Client::ResponseNotification, id: initial_va_notify_id)
      retry_responses = Array.new(EventBusGateway::Constants::MAX_EMAIL_ATTEMPTS - 2) do |i|
        instance_double(Notifications::Client::ResponseNotification, id: "retry-#{i}-#{SecureRandom.uuid}")
      end

      expect(va_notify_service).to receive(:send_email)
        .exactly(EventBusGateway::Constants::MAX_EMAIL_ATTEMPTS - 1).times
        .and_return(initial_response, *retry_responses)

      # Step 1: Initial email job
      EventBusGateway::LetterReadyEmailJob.perform_async(participant_id, template_id)
      Sidekiq::Worker.drain_all

      notification = EventBusGatewayNotification.last
      expect(notification.attempts).to eq(1)
      temp_failure = create_notification_double(notification.va_notify_id, 'temporary-failure')

      EventBusGateway::VANotifyEmailStatusCallback.call(temp_failure)

      # Step 2: Simulate the remaining temporary failures up to one below MAX_EMAIL_ATTEMPTS.
      (EventBusGateway::Constants::MAX_EMAIL_ATTEMPTS - 2).times do |attempt|
        expect(EventBusGateway::LetterReadyRetryEmailJob.jobs.size).to eq(1)
        Sidekiq::Worker.drain_all
        notification.reload
        expect(notification.attempts).to eq(attempt + 2)

        temp_failure = create_notification_double(notification.va_notify_id, 'temporary-failure')

        EventBusGateway::VANotifyEmailStatusCallback.call(temp_failure)
      end

      expect(notification.attempts).to eq(EventBusGateway::Constants::MAX_EMAIL_ATTEMPTS - 1)

      expect(EventBusGateway::LetterReadyRetryEmailJob.jobs.length).to eq(1)
      expect(StatsD).not_to have_received(:increment)
        .with('event_bus_gateway.va_notify_email_status_callback.exhausted_retries',
              tags: EventBusGateway::Constants::DD_TAGS)
      expect(Rails.logger).not_to have_received(:error)
        .with('EventBusGateway email retries exhausted',
              { ebg_notification_id: notification.id,
                max_attempts: EventBusGateway::Constants::MAX_EMAIL_ATTEMPTS })
    end

    it 'retries twice after multiple temporary failures, then succeeds' do
      # Mock all email sends
      initial_response = instance_double(Notifications::Client::ResponseNotification, id: initial_va_notify_id)
      retry_response_first = instance_double(Notifications::Client::ResponseNotification, id: retry_va_notify_id)
      retry_response_second = instance_double(Notifications::Client::ResponseNotification,
                                              id: retry_va_notify_id_second)

      expect(va_notify_service).to receive(:send_email).exactly(3).times
                                                       .and_return(initial_response, retry_response_first,
                                                                   retry_response_second)

      # Step 1: Initial email job
      EventBusGateway::LetterReadyEmailJob.perform_async(participant_id, template_id)
      Sidekiq::Worker.drain_all

      notification = EventBusGatewayNotification.last
      expect(notification.attempts).to eq(1)

      # Step 2: First temporary failure (use actual va_notify_id from notification)
      temp_failure_first = create_notification_double(notification.va_notify_id, 'temporary-failure')
      EventBusGateway::VANotifyEmailStatusCallback.call(temp_failure_first)
      expect(EventBusGateway::LetterReadyRetryEmailJob.jobs.size).to eq(1)

      # Process first retry
      Sidekiq::Worker.drain_all
      notification.reload
      expect(notification.attempts).to eq(2)
      expect(notification.va_notify_id).to eq(retry_va_notify_id)

      # Step 3: Second temporary failure (use updated va_notify_id from notification)
      temp_failure_second = create_notification_double(notification.va_notify_id, 'temporary-failure')

      EventBusGateway::VANotifyEmailStatusCallback.call(temp_failure_second)
      expect(EventBusGateway::LetterReadyRetryEmailJob.jobs.size).to eq(1)

      # Process second retry
      Sidekiq::Worker.drain_all
      notification.reload
      expect(notification.attempts).to eq(3)
      expect(notification.va_notify_id).to eq(retry_va_notify_id_second)

      # Step 4: Finally delivered (use final va_notify_id)
      delivered_final = create_notification_double(notification.va_notify_id, 'delivered',
                                                   status_reason: 'delivered')

      EventBusGateway::VANotifyEmailStatusCallback.call(delivered_final)

      # Verify no more retries queued
      expect(EventBusGateway::LetterReadyRetryEmailJob.jobs).to be_empty

      # Verify success metrics recorded twice
      expect(StatsD).to have_received(:increment)
        .with('event_bus_gateway.va_notify_email_status_callback.queued_retry_success',
              tags: EventBusGateway::Constants::DD_TAGS).twice
    end

    it 'exhausts retries after reaching MAX_EMAIL_ATTEMPTS' do
      initial_response = instance_double(Notifications::Client::ResponseNotification, id: initial_va_notify_id)
      retry_responses = Array.new(EventBusGateway::Constants::MAX_EMAIL_ATTEMPTS - 1) do |i|
        instance_double(Notifications::Client::ResponseNotification, id: "retry-#{i}-#{SecureRandom.uuid}")
      end

      expect(va_notify_service).to receive(:send_email)
        .exactly(EventBusGateway::Constants::MAX_EMAIL_ATTEMPTS).times
        .and_return(initial_response, *retry_responses)

      # Step 1: Initial email job
      EventBusGateway::LetterReadyEmailJob.perform_async(participant_id, template_id)
      Sidekiq::Worker.drain_all

      notification = EventBusGatewayNotification.last
      expect(notification.attempts).to eq(1)
      temp_failure = create_notification_double(notification.va_notify_id, 'temporary-failure')

      EventBusGateway::VANotifyEmailStatusCallback.call(temp_failure)

      # Step 2: Simulate the remaining temporary failures up to MAX_EMAIL_ATTEMPTS
      (EventBusGateway::Constants::MAX_EMAIL_ATTEMPTS - 1).times do |attempt|
        # Should queue retry if not at max attempts
        expect(EventBusGateway::LetterReadyRetryEmailJob.jobs.size).to eq(1)
        Sidekiq::Worker.drain_all
        notification.reload
        expect(notification.attempts).to eq(attempt + 2)

        # Create a temporary failure notification with the current va_notify_id
        temp_failure = create_notification_double(notification.va_notify_id, 'temporary-failure')

        EventBusGateway::VANotifyEmailStatusCallback.call(temp_failure)
      end

      expect(notification.attempts).to eq(EventBusGateway::Constants::MAX_EMAIL_ATTEMPTS) # initial + remaining retries

      # Verify no retry job queued and exhausted retry logged
      expect(EventBusGateway::LetterReadyRetryEmailJob.jobs).to be_empty
      expect(StatsD).to have_received(:increment)
        .with('event_bus_gateway.va_notify_email_status_callback.exhausted_retries',
              tags: EventBusGateway::Constants::DD_TAGS)
      expect(Rails.logger).to have_received(:error)
        .with('EventBusGateway email retries exhausted',
              { ebg_notification_id: notification.id,
                max_attempts: EventBusGateway::Constants::MAX_EMAIL_ATTEMPTS })
    end
  end

  describe 'Email retry flows with event_bus_gateway_retry_emails disabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_retry_emails).and_return(false)
    end

    it 'does not retry on temporary failure when feature flag is disabled' do
      # Mock initial email send
      email_response = instance_double(Notifications::Client::ResponseNotification, id: initial_va_notify_id)
      expect(va_notify_service).to receive(:send_email).once.and_return(email_response)

      # Step 1: Initial email job
      EventBusGateway::LetterReadyEmailJob.perform_async(participant_id, template_id)
      Sidekiq::Worker.drain_all

      notification = EventBusGatewayNotification.last
      expect(notification.attempts).to eq(1)

      # Step 2: Temporary failure callback (use actual notification va_notify_id)
      temp_failure_disabled = create_notification_double(notification.va_notify_id, 'temporary-failure')

      EventBusGateway::VANotifyEmailStatusCallback.call(temp_failure_disabled)

      # Verify no retry job was queued
      expect(EventBusGateway::LetterReadyRetryEmailJob.jobs).to be_empty

      # Verify temporary failure metrics recorded
      expect(StatsD).to have_received(:increment)
        .with('callbacks.event_bus_gateway.va_notify.notifications.temporary_failure')
    end
  end

  describe 'Error handling in end-to-end flow' do
    before do
      allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_retry_emails).and_return(true)
    end

    it 'handles EventBusGatewayNotificationNotFoundError during retry callback' do
      # Mock initial email send
      email_response = instance_double(Notifications::Client::ResponseNotification, id: initial_va_notify_id)
      expect(va_notify_service).to receive(:send_email).once.and_return(email_response)

      # Step 1: Initial email job
      EventBusGateway::LetterReadyEmailJob.perform_async(participant_id, template_id)
      Sidekiq::Worker.drain_all

      notification = EventBusGatewayNotification.last

      # Step 2: Delete the notification to simulate not found scenario
      EventBusGatewayNotification.destroy_all

      # Step 3: Temporary failure callback should raise error (use the deleted notification's va_notify_id)
      temp_failure_not_found = create_notification_double(notification.va_notify_id, 'temporary-failure')

      expect do
        EventBusGateway::VANotifyEmailStatusCallback.call(temp_failure_not_found)
      end.to raise_error(EventBusGateway::VANotifyEmailStatusCallback::EventBusGatewayNotificationNotFoundError)

      # Verify failure metric was recorded
      expect(StatsD).to have_received(:increment)
        .with('event_bus_gateway.va_notify_email_status_callback.queued_retry_failure',
              tags: EventBusGateway::Constants::DD_TAGS + ['function: EventBusGateway::VANotifyEmailStatusCallback::EventBusGatewayNotificationNotFoundError'])
    end

    it 'handles MPI errors during retry scheduling' do
      # Mock initial email send
      email_response = instance_double(Notifications::Client::ResponseNotification, id: initial_va_notify_id)
      expect(va_notify_service).to receive(:send_email).once.and_return(email_response)

      # Step 1: Initial email job
      EventBusGateway::LetterReadyEmailJob.perform_async(participant_id, template_id)
      Sidekiq::Worker.drain_all

      notification = EventBusGatewayNotification.last

      # Step 2: Mock MPI failure for retry scheduling
      mpi_error_response = instance_double(MPI::Responses::FindProfileResponse, ok?: false)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier)
        .and_return(mpi_error_response)

      # Step 3: Temporary failure callback should raise MPIError (use actual notification va_notify_id)
      temp_failure_for_mpi_test = create_notification_double(notification.va_notify_id, 'temporary-failure')

      expect do
        EventBusGateway::VANotifyEmailStatusCallback.call(temp_failure_for_mpi_test)
      end.to raise_error(EventBusGateway::VANotifyEmailStatusCallback::MPIError)

      # Verify failure metric was recorded
      expect(StatsD).to have_received(:increment)
        .with('event_bus_gateway.va_notify_email_status_callback.queued_retry_failure',
              tags: EventBusGateway::Constants::DD_TAGS + ['function: EventBusGateway::VANotifyEmailStatusCallback::MPIError'])
    end
  end
end
