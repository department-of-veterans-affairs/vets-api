# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::TravelClaimNotificationJob do
  let(:uuid) { '1234-5678-9012' }
  let(:mobile_phone) { '202-555-0123' }
  let(:appointment_date) { '2023-05-15' }
  let(:claim_number) { '1234' }
  let(:facility_type) { 'oh' }
  let(:template_id) { 'template-id-123' }
  let(:redis_client) { instance_double(TravelClaim::RedisClient) }
  let(:formatted_date) { DateTime.strptime(appointment_date, '%Y-%m-%d').to_date.strftime('%b %d') }
  let(:parsed_date) { DateTime.strptime(appointment_date, '%Y-%m-%d').to_date }
  let(:notify_client) { instance_double(VaNotify::Service) }
  let(:test_logger) { instance_double(Logger) }

  before do
    allow(VaNotify::Service).to receive(:new).and_return(notify_client)
    allow(notify_client).to receive(:send_sms)
    allow_any_instance_of(described_class).to receive(:logger).and_return(test_logger)
    allow(test_logger).to receive(:info)
    allow(Settings.vanotify.services.check_in).to receive(:api_key).and_return('test-api-key')
    allow(StatsD).to receive(:increment)

    allow(TravelClaim::RedisClient).to receive(:build).and_return(redis_client)
    allow(redis_client).to receive(:patient_cell_phone).with(uuid:).and_return(mobile_phone)
    allow(redis_client).to receive(:mobile_phone).with(uuid:).and_return(nil)
    allow(redis_client).to receive(:facility_type).with(uuid:).and_return(facility_type)
  end

  describe '#perform' do
    it 'successfully completes SMS notification API request using the provided claim number' do
      expect(notify_client).to receive(:send_sms).with(
        phone_number: mobile_phone,
        template_id:,
        sms_sender_id: CheckIn::Constants::OH_SMS_SENDER_ID,
        personalisation: { claim_number:, appt_date: formatted_date }
      )

      expect(test_logger).to receive(:info).with(
        hash_including(
          message: 'Sending Travel Claim Notification SMS',
          uuid:,
          phone_last_four: '0123',
          template_id:
        )
      )

      expect(test_logger).to receive(:info).with(
        hash_including(
          message: 'Travel Claim Notification SMS API request succeeded',
          uuid:,
          phone_last_four: '0123',
          template_id:
        )
      )

      described_class.new.perform(uuid, appointment_date, template_id, claim_number)

      expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_SUCCESS)
    end

    it 'skips SMS sending and logs when mobile phone is missing' do
      allow(redis_client).to receive(:patient_cell_phone).with(uuid:).and_return(nil)
      allow(redis_client).to receive(:mobile_phone).with(uuid:).and_return(nil)
      job = described_class.new

      expect(notify_client).not_to receive(:send_sms)
      expect(StatsD).to receive(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
      expect(test_logger).to receive(:info).with(
        hash_including(
          message: "Failed to send Travel Claim Notification SMS: missing mobile_phone, Won't Retry",
          uuid:,
          phone_last_four: 'unknown',
          template_id:
        )
      )

      job.perform(uuid, appointment_date, template_id, claim_number)
    end

    it 'successfully completes SMS API request when claim number is missing' do
      job = described_class.new

      expect(notify_client).to receive(:send_sms)
      expect(test_logger).to receive(:info).with(
        hash_including(
          message: 'Travel Claim Notification SMS API request succeeded'
        )
      )
      expect(StatsD).to receive(:increment).with(CheckIn::Constants::STATSD_NOTIFY_SUCCESS)

      job.perform(uuid, appointment_date, template_id, nil)
    end

    it 'skips SMS sending and logs when appointment date is invalid' do
      invalid_date = 'invalid-date'
      job = described_class.new
      message = "Failed to send Travel Claim Notification SMS: invalid appointment date format, Won't Retry"

      expect(notify_client).not_to receive(:send_sms)
      expect(StatsD).to receive(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
      expect(test_logger).to receive(:info).with(
        hash_including(
          message:,
          uuid:,
          phone_last_four: '0123',
          template_id:
        )
      )

      expect { job.perform(uuid, invalid_date, template_id, claim_number) }.not_to raise_error
    end

    context 'when an error occurs during SMS sending' do
      before do
        allow(notify_client).to receive(:send_sms).and_raise(StandardError.new('Test error'))
      end

      it 'logs failures and raises the error' do
        job = described_class.new

        expect(test_logger).to receive(:info).with(
          hash_including(
            message: 'Sending Travel Claim Notification SMS',
            uuid:,
            phone_last_four: '0123',
            template_id:
          )
        )

        expect(test_logger).to receive(:info).with(
          hash_including(
            message: 'Failed to send Travel Claim Notification SMS: Test error',
            uuid:,
            phone_last_four: '0123',
            template_id:
          )
        )

        expect do
          job.perform(uuid, appointment_date, template_id, claim_number)
        end.to raise_error(StandardError)
      end

      it 'logs only the last 4 digits of the phone number in error messages' do
        job = described_class.new
        expect(test_logger).to receive(:info).with(
          hash_including(
            message: 'Sending Travel Claim Notification SMS',
            uuid:,
            phone_last_four: '0123',
            template_id:
          )
        )

        expect(test_logger).to receive(:info).with(
          hash_including(
            message: 'Failed to send Travel Claim Notification SMS: Test error',
            uuid:,
            phone_last_four: '0123',
            template_id:
          )
        ).ordered

        expect(test_logger).not_to receive(:info).with(
          hash_including(message: /202-555-0123/)
        )

        expect do
          job.perform(uuid, appointment_date, template_id, claim_number)
        end.to raise_error(StandardError)
      end
    end
  end

  describe 'retry configuration' do
    it 'has retry setting configured to 12' do
      sidekiq_retry_value = described_class.sidekiq_options_hash['retry']
      expect(sidekiq_retry_value).to eq(12)
    end
  end

  describe 'error handling and facility type handling' do
    let(:error) { StandardError.new('Test error') }

    it 'handles errors correctly when retries are exhausted with OH facility' do
      allow(Settings.vanotify.services.oracle_health.template_id)
        .to receive(:claim_submission_failure_text).and_return('oh-failure-template-id')

      template_id = 'oh-failure-template-id'
      job_hash = { 'args' => [uuid, appointment_date, template_id, claim_number], 'error_message' => 'Test error' }

      expect(SentryLogging).to receive(:log_exception_to_sentry).with(
        error,
        hash_including(template_id:, claim_number:, phone_last_four: '0123'),
        hash_including(error: :check_in_va_notify_job, team: 'check-in')
      )

      described_class.sidekiq_retries_exhausted_block.call(job_hash, error)

      expect(StatsD).to have_received(:increment).with(
        CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
        tags: CheckIn::Constants::STATSD_OH_SILENT_FAILURE_TAGS
      )
      expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
    end

    it 'handles errors correctly when retries are exhausted with CIE facility' do
      allow(Settings.vanotify.services.check_in.template_id)
        .to receive(:claim_submission_failure_text).and_return('cie-failure-template-id')

      template_id = 'cie-failure-template-id'
      job_hash = { 'args' => [uuid, appointment_date, template_id, claim_number] }

      described_class.handle_retries_exhausted_failure(job_hash, error)

      expect(StatsD).to have_received(:increment).with(
        CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
        tags: CheckIn::Constants::STATSD_CIE_SILENT_FAILURE_TAGS
      )
      expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
    end

    it 'handles errors correctly with regular templates' do
      template_id = 'regular-template-id'
      job_hash = { 'args' => [uuid, appointment_date, template_id, claim_number] }

      described_class.handle_retries_exhausted_failure(job_hash, error)

      expect(StatsD).not_to have_received(:increment).with(
        CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
        any_args
      )
      expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
    end

    it 'logs template ID to Sentry' do
      allow(Settings.vanotify.services.oracle_health.template_id)
        .to receive(:claim_submission_failure_text).and_return('oh-failure-template-id')

      template_id = 'oh-failure-template-id'
      job_hash = { 'args' => [uuid, appointment_date, template_id, claim_number], 'error_message' => 'Test error' }

      expect(SentryLogging).to receive(:log_exception_to_sentry).with(
        error,
        hash_including(template_id:, claim_number:, phone_last_four: '0123'),
        any_args
      )

      described_class.sidekiq_retries_exhausted_block.call(job_hash, error)
    end
  end

  describe 'SMS sender ID selection' do
    it 'uses appropriate SMS sender ID based on facility type' do
      allow(redis_client).to receive(:facility_type).with(uuid:).and_return('oh')

      expect(notify_client).to receive(:send_sms).with(
        phone_number: mobile_phone,
        template_id:,
        sms_sender_id: CheckIn::Constants::OH_SMS_SENDER_ID,
        personalisation: { claim_number:, appt_date: formatted_date }
      )

      described_class.new.perform(uuid, appointment_date, template_id, claim_number)

      allow(redis_client).to receive(:facility_type).with(uuid:).and_return('cie')

      expect(notify_client).to receive(:send_sms).with(
        phone_number: mobile_phone,
        template_id:,
        sms_sender_id: CheckIn::Constants::CIE_SMS_SENDER_ID,
        personalisation: { claim_number:, appt_date: formatted_date }
      )

      described_class.new.perform(uuid, appointment_date, template_id, claim_number)
    end
  end
end
