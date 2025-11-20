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
    allow(Rails).to receive(:logger).and_return(test_logger)
    allow(test_logger).to receive(:info)
    allow(test_logger).to receive(:error)
    allow(test_logger).to receive(:send)
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
        sms_sender_id: CheckIn::Constants::CIE_SMS_SENDER_ID,
        personalisation: { claim_number:, appt_date: formatted_date }
      )

      expect(test_logger).to receive(:send).with(:info, 'CheckIn::TravelClaimNotificationJob',
                                                 hash_including(
                                                   message: 'CheckIn::TravelClaimNotificationJob: ' \
                                                            'Sending Travel Claim Notification SMS',
                                                   phone_last_four: '0123',
                                                   template_id:,
                                                   status: 'sending'
                                                 ))

      expect(test_logger).to receive(:send).with(:info, 'CheckIn::TravelClaimNotificationJob',
                                                 hash_including(
                                                   message: 'CheckIn::TravelClaimNotificationJob: ' \
                                                            'Travel Claim Notification SMS API ' \
                                                            'request succeeded',
                                                   phone_last_four: '0123',
                                                   template_id:,
                                                   status: 'success'
                                                 ))

      described_class.new.perform(uuid, appointment_date, template_id, claim_number)

      expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_SUCCESS)
    end

    it 'skips SMS sending and logs when mobile phone is missing' do
      allow(redis_client).to receive(:patient_cell_phone).with(uuid:).and_return(nil)
      allow(redis_client).to receive(:mobile_phone).with(uuid:).and_return(nil)
      job = described_class.new

      expect(notify_client).not_to receive(:send_sms)
      expect(StatsD).to receive(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
      expect(test_logger).to receive(:send).with(:error, 'CheckIn::TravelClaimNotificationJob',
                                                 hash_including(
                                                   message: 'CheckIn::TravelClaimNotificationJob: ' \
                                                            'Failed to send Travel Claim Notification SMS: ' \
                                                            "missing phone_number, Won't Retry",
                                                   uuid:,
                                                   status: 'failed_no_retry',
                                                   template_id:,
                                                   phone_last_four: 'unknown'
                                                 ))

      job.perform(uuid, appointment_date, template_id, claim_number)
    end

    it 'successfully completes SMS API request when claim number is missing' do
      job = described_class.new

      expect(notify_client).to receive(:send_sms)
      expect(test_logger).to receive(:send).with(:info, 'CheckIn::TravelClaimNotificationJob',
                                                 hash_including(
                                                   message: 'CheckIn::TravelClaimNotificationJob: ' \
                                                            'Travel Claim Notification SMS API ' \
                                                            'request succeeded',
                                                   status: 'success'
                                                 ))
      expect(StatsD).to receive(:increment).with(CheckIn::Constants::STATSD_NOTIFY_SUCCESS)

      job.perform(uuid, appointment_date, template_id, nil)
    end

    it 'skips SMS sending and logs when appointment date is invalid' do
      invalid_date = 'invalid-date'
      job = described_class.new
      message = 'CheckIn::TravelClaimNotificationJob: Failed to send Travel Claim Notification SMS: ' \
                "invalid appointment date format, Won't Retry"

      expect(notify_client).not_to receive(:send_sms)
      expect(StatsD).to receive(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
      expect(test_logger).to receive(:send).with(:error, 'CheckIn::TravelClaimNotificationJob',
                                                 hash_including(
                                                   message:,
                                                   uuid:,
                                                   status: 'failed_no_retry'
                                                 ))

      expect { job.perform(uuid, invalid_date, template_id, claim_number) }.not_to raise_error
    end

    context 'when an error occurs during SMS sending' do
      before do
        allow(notify_client).to receive(:send_sms).and_raise(StandardError.new('Test error'))
      end

      it 'logs failures and raises the error' do
        job = described_class.new

        expect(test_logger).to receive(:send).with(:info, 'CheckIn::TravelClaimNotificationJob',
                                                   hash_including(
                                                     message: 'CheckIn::TravelClaimNotificationJob: ' \
                                                              'Sending Travel Claim Notification SMS',
                                                     phone_last_four: '0123',
                                                     template_id:,
                                                     status: 'sending'
                                                   ))

        expect(test_logger).to receive(:send).with(:error, 'CheckIn::TravelClaimNotificationJob',
                                                   hash_including(
                                                     message: 'CheckIn::TravelClaimNotificationJob: ' \
                                                              'Failed to send Travel Claim ' \
                                                              'Notification SMS: Test error',
                                                     uuid:,
                                                     status: 'failed'
                                                   ))

        expect do
          job.perform(uuid, appointment_date, template_id, claim_number)
        end.to raise_error(StandardError)
      end

      it 'logs UUID only for error messages, not for info messages' do
        job = described_class.new
        expect(test_logger).to receive(:send).with(:info, 'CheckIn::TravelClaimNotificationJob',
                                                   hash_including(
                                                     message: 'CheckIn::TravelClaimNotificationJob: ' \
                                                              'Sending Travel Claim Notification SMS',
                                                     phone_last_four: '0123',
                                                     template_id:,
                                                     status: 'sending'
                                                   ))

        expect(test_logger).to receive(:send).with(:error, 'CheckIn::TravelClaimNotificationJob',
                                                   hash_including(
                                                     message: 'CheckIn::TravelClaimNotificationJob: ' \
                                                              'Failed to send Travel Claim ' \
                                                              'Notification SMS: Test error',
                                                     uuid:,
                                                     status: 'failed'
                                                   )).ordered

        expect(test_logger).not_to receive(:info).with(
          hash_including(uuid:)
        )

        expect do
          job.perform(uuid, appointment_date, template_id, claim_number)
        end.to raise_error(StandardError)
      end
    end
  end

  describe 'retry configuration' do
    it 'has retry setting configured to 14' do
      sidekiq_retry_value = described_class.sidekiq_options_hash['retry']
      expect(sidekiq_retry_value).to eq(14)
    end
  end

  describe 'error handling and facility type handling' do
    let(:error) { StandardError.new('Test error') }

    it 'handles errors correctly when retries are exhausted with OH facility' do
      allow(Settings.vanotify.services.oracle_health.template_id)
        .to receive(:claim_submission_failure_text).and_return('oh-failure-template-id')

      template_id = 'oh-failure-template-id'
      job_hash = { 'args' => [uuid, appointment_date, template_id, claim_number], 'error_message' => 'Test error' }

      logging_helper = double('logging_helper')
      allow(described_class).to receive(:logging_helper).and_return(logging_helper)
      allow(logging_helper).to receive(:log_exception_to_sentry)
      expect(logging_helper).to receive(:log_exception_to_sentry).with(
        error,
        hash_including(template_id:, claim_number:, phone_last_four: '0123'),
        hash_including(error: :check_in_va_notify_job, team: 'check-in')
      )
      expect(Rails.logger).to receive(:error).with(
        include("Travel Claim Notification retries exhausted: #{error.message}")
      )

      allow(described_class).to receive(:handle_retries_exhausted) do |_job, ex|
        phone_last_four = CheckIn::TravelClaimNotificationUtilities.extract_phone_last_four(mobile_phone)
        logging_helper.log_exception_to_sentry(
          ex,
          { template_id:, phone_last_four:, claim_number: },
          { error: :check_in_va_notify_job, team: 'check-in' }
        )
        context_hash = { template_id:, phone_last_four:, claim_number: }
        Rails.logger.error("Travel Claim Notification retries exhausted: #{ex.message} - Context: #{context_hash}")
        described_class.log_failure_no_retry('Retries exhausted', { template_id:, facility_type: 'oh' })
      end

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

      logging_helper = double('logging_helper')
      allow(described_class).to receive(:logging_helper).and_return(logging_helper)
      allow(logging_helper).to receive(:log_exception_to_sentry)

      described_class.handle_retries_exhausted(job_hash, error)

      expect(StatsD).to have_received(:increment).with(
        CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
        tags: CheckIn::Constants::STATSD_CIE_SILENT_FAILURE_TAGS
      )
      expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
    end

    it 'handles errors correctly with regular templates' do
      template_id = 'regular-template-id'
      job_hash = { 'args' => [uuid, appointment_date, template_id, claim_number] }

      logging_helper = double('logging_helper')
      allow(described_class).to receive(:logging_helper).and_return(logging_helper)
      allow(logging_helper).to receive(:log_exception_to_sentry)

      described_class.handle_retries_exhausted(job_hash, error)

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

      logging_helper = double('logging_helper')
      allow(described_class).to receive(:logging_helper).and_return(logging_helper)
      allow(logging_helper).to receive(:log_exception_to_sentry)
      expect(logging_helper).to receive(:log_exception_to_sentry).with(
        error,
        hash_including(template_id:, claim_number:, phone_last_four: '0123'),
        any_args
      )
      expect(Rails.logger).to receive(:error).with(
        include("Travel Claim Notification retries exhausted: #{error.message}")
      )

      described_class.sidekiq_retries_exhausted_block.call(job_hash, error)
    end
  end

  describe 'SMS sender ID selection' do
    it 'uses appropriate SMS sender ID based on facility type derived from template' do
      # Test with OH template (using actual OH template that will be recognized)
      oh_template = 'oh-failure-template-id'

      expect(notify_client).to receive(:send_sms).with(
        phone_number: mobile_phone,
        template_id: oh_template,
        sms_sender_id: CheckIn::Constants::OH_SMS_SENDER_ID,
        personalisation: { claim_number:, appt_date: formatted_date }
      )

      described_class.new.perform(uuid, appointment_date, oh_template, claim_number)

      # Test with CIE template (generic templates now default to CIE)
      cie_template = 'some-generic-template-id'

      expect(notify_client).to receive(:send_sms).with(
        phone_number: mobile_phone,
        template_id: cie_template,
        sms_sender_id: CheckIn::Constants::CIE_SMS_SENDER_ID,
        personalisation: { claim_number:, appt_date: formatted_date }
      )

      described_class.new.perform(uuid, appointment_date, cie_template, claim_number)
    end
  end
end
