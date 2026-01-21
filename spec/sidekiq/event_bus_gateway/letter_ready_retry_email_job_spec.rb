# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/service'
require_relative '../../../app/sidekiq/event_bus_gateway/constants'

RSpec.describe EventBusGateway::LetterReadyRetryEmailJob, type: :job do
  subject { described_class }

  let(:notification_id) { existing_notification.id }
  let!(:existing_notification) do
    create(:event_bus_gateway_notification,
           template_id:,
           attempts: 1,
           va_notify_id: 'original-va-notify-id')
  end
  let(:va_notify_service) do
    service = instance_double(VaNotify::Service)
    response = instance_double(Notifications::Client::ResponseNotification, id: va_notify_response_id)
    allow(service).to receive(:send_email).and_return(response)
    service
  end
  let(:va_notify_response_id) { SecureRandom.uuid }
  let(:personalisation) { { host: 'localhost', first_name: 'Joe' } }
  let(:template_id) { '5678' }
  let(:participant_id) { '1234' }

  describe 'EventBusGatewayNotificationNotFoundError' do
    it 'is defined as a custom exception' do
      expect(EventBusGateway::LetterReadyRetryEmailJob::EventBusGatewayNotificationNotFoundError).to be < StandardError
    end
  end

  context 'when an error does not occur' do
    before do
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
      allow(StatsD).to receive(:increment)
    end

    it 'sends an email using VA Notify and updates the existing EventBusGatewayNotification' do
      expected_args = {
        recipient_identifier: { id_value: participant_id, id_type: 'PID' },
        template_id:,
        personalisation:
      }

      expect(va_notify_service).to receive(:send_email).with(expected_args)
      expect(StatsD).to receive(:increment)
        .with("#{described_class::STATSD_METRIC_PREFIX}.success", tags: EventBusGateway::Constants::DD_TAGS)

      expect do
        subject.new.perform(participant_id, template_id, personalisation, notification_id)
      end.not_to change(EventBusGatewayNotification, :count)

      # Check that the existing notification was updated
      existing_notification.reload
      expect(existing_notification.attempts).to eq(2)
      expect(existing_notification.va_notify_id).to eq(va_notify_response_id)
    end
  end

  context 'when a VA Notify error occurs during email sending' do
    before do
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
      allow(va_notify_service).to receive(:send_email).and_raise(StandardError, 'VA Notify email error')
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    let(:error_message) { 'LetterReadyRetryEmailJob email error' }
    let(:message_detail) { 'VA Notify email error' }
    let(:tags) { EventBusGateway::Constants::DD_TAGS + ["function: #{error_message}"] }

    it 'does not send an email successfully, logs the error, increments the statsd metric, and re-raises for retry' do
      expect(Rails.logger)
        .to receive(:error)
        .with(error_message, { message: message_detail })
      expect(StatsD).to receive(:increment).with("#{described_class::STATSD_METRIC_PREFIX}.failure", tags:)

      expect do
        subject.new.perform(participant_id, template_id, personalisation, notification_id)
      end.to raise_error(StandardError, message_detail).and not_change(EventBusGatewayNotification, :count)

      # Notification should remain unchanged since email send failed
      existing_notification.reload
      expect(existing_notification.attempts).to eq(1)
      expect(existing_notification.va_notify_id).to eq('original-va-notify-id')
    end
  end

  context 'when notification record is not found' do
    before do
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    it 'raises EventBusGatewayNotificationNotFoundError, logs failure, and re-raises for retry' do
      non_existent_id = SecureRandom.uuid

      expect(va_notify_service).not_to receive(:send_email)
      expect(Rails.logger).to receive(:error)
        .with('LetterReadyRetryEmailJob email error',
              { message: match(/EventBusGatewayNotificationNotFoundError/) })
      expect(StatsD).to receive(:increment)
        .with("#{described_class::STATSD_METRIC_PREFIX}.failure",
              tags: EventBusGateway::Constants::DD_TAGS + ['function: LetterReadyRetryEmailJob email error'])

      expect do
        subject.new.perform(participant_id, template_id, personalisation, non_existent_id)
      end.to raise_error(EventBusGateway::LetterReadyRetryEmailJob::EventBusGatewayNotificationNotFoundError)
    end

    it 'raises EventBusGatewayNotificationNotFoundError when notification_id is nil and re-raises for retry' do
      expect(va_notify_service).not_to receive(:send_email)
      expect(Rails.logger).to receive(:error)
        .with('LetterReadyRetryEmailJob email error',
              { message: match(/EventBusGatewayNotificationNotFoundError/) })
      expect(StatsD).to receive(:increment)
        .with("#{described_class::STATSD_METRIC_PREFIX}.failure",
              tags: EventBusGateway::Constants::DD_TAGS + ['function: LetterReadyRetryEmailJob email error'])

      expect do
        subject.new.perform(participant_id, template_id, personalisation, nil)
      end.to raise_error(EventBusGateway::LetterReadyRetryEmailJob::EventBusGatewayNotificationNotFoundError)
    end
  end

  context 'when sidekiq retries are exhausted' do
    before do
      allow(Rails.logger).to receive(:error)
      allow(StatsD).to receive(:increment)
    end

    let(:job_id) { 'test-job-id-123' }
    let(:error_class) { 'StandardError' }
    let(:error_message) { 'Some error message' }
    let(:msg) do
      {
        'jid' => job_id,
        'error_class' => error_class,
        'error_message' => error_message
      }
    end
    let(:exception) { StandardError.new(error_message) }

    it 'logs the exhausted retries and increments the statsd metric' do
      # Get the retries exhausted callback from the job class
      retries_exhausted_callback = described_class.sidekiq_retries_exhausted_block

      expect(Rails.logger).to receive(:error)
        .with('LetterReadyRetryEmailJob retries exhausted', {
                job_id:,
                timestamp: be_within(1.second).of(Time.now.utc),
                error_class:,
                error_message:
              })

      expect(StatsD).to receive(:increment)
        .with("#{described_class::STATSD_METRIC_PREFIX}.exhausted",
              tags: EventBusGateway::Constants::DD_TAGS)

      retries_exhausted_callback.call(msg, exception)
    end
  end

  describe 'Retry count limit.' do
    it "Sets Sidekiq retry count to #{EventBusGateway::Constants::SIDEKIQ_RETRY_COUNT_RETRY_EMAIL}." do
      expect(described_class.sidekiq_options['retry']).to eq(EventBusGateway::Constants::SIDEKIQ_RETRY_COUNT_RETRY_EMAIL)
    end
  end
end
