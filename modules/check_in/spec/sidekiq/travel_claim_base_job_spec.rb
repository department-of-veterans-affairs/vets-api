# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::TravelClaimBaseJob do
  let(:mobile_phone) { '202-555-0123' }
  let(:appointment_date) { '2023-05-15' }
  let(:claim_number) { '1234' }
  let(:facility_type) { 'oh' }
  let(:template_id) { 'template-id-123' }
  let(:job_opts) do
    {
      mobile_phone:,
      appointment_date:,
      template_id:,
      claim_number:,
      facility_type:
    }
  end

  describe 'retry configuration' do
    it 'has MAX_RETRIES matching sidekiq_options retry setting' do
      sidekiq_retry_value = described_class.sidekiq_options_hash['retry']
      expect(described_class::MAX_RETRIES).to eq(sidekiq_retry_value)
    end
  end

  describe '#send_notification' do
    subject { described_class.new.send_notification(job_opts) }

    before do
      allow_any_instance_of(VaNotify::Service).to receive(:send_sms)
      allow_any_instance_of(described_class).to receive(:logger).and_return(Logger.new(nil))
    end

    it 'successfully sends SMS notification via VaNotify service' do
      notify_client = instance_double(VaNotify::Service)
      allow(VaNotify::Service).to receive(:new).and_return(notify_client)

      formatted_date = DateTime.strptime(appointment_date, '%Y-%m-%d').to_date.strftime('%b %d')


      expect(notify_client).to receive(:send_sms).with(
        phone_number: mobile_phone,
        template_id:,
        sms_sender_id: CheckIn::Constants::OH_SMS_SENDER_ID,
        personalisation: { claim_number:, appt_date: formatted_date }
      )

      subject
    end

    context 'when an error occurs' do
      before do
        allow_any_instance_of(VaNotify::Service).to receive(:send_sms)
          .and_raise(StandardError.new('Test error'))
      end

      it 'logs failures with incrementing retry counts' do
        test_logger = instance_double(Logger)
        allow_any_instance_of(described_class).to receive(:logger).and_return(test_logger)

        # First attempt - retry_count = 0
        job = described_class.new

        expect(test_logger).to receive(:info).with(hash_including(
          message: "Sending travel claim notification to 0123, template-id-123"
        ))
        expect(test_logger).to receive(:info).with(hash_including(
          message: "Sending SMS failed, attempt 1 of #{described_class::MAX_RETRIES}"
        ))
        expect { job.send_notification(job_opts) }.to raise_error(StandardError)

        # Second attempt - retry_count = 1
        job = described_class.new
        allow(job.class).to receive(:sidekiq_options_hash).and_return({ 'retry_count' => 1 })

        expect(test_logger).to receive(:info).with(hash_including(
          message: "Sending travel claim notification to 0123, template-id-123"
        ))
        expect(test_logger).to receive(:info).with(hash_including(
          message: "Sending SMS failed, attempt 2 of #{described_class::MAX_RETRIES}"
        ))
        expect { job.send_notification(job_opts) }.to raise_error(StandardError)
      end
    end

    context 'when retry mechanism is exhausted' do
      before do
        allow_any_instance_of(VaNotify::Service).to receive(:send_sms)
          .and_raise(StandardError.new('Test error'))
      end

      it 'handles errors correctly when retries are exhausted' do
        oh_job_opts = job_opts.merge(template_id: CheckIn::Constants::OH_FAILURE_TEMPLATE_ID)
        error = StandardError.new('Test error')

        job_hash = {
          'args' => [oh_job_opts],
          'error_message' => 'Test error'
        }

        expect(SentryLogging).to receive(:log_exception_to_sentry).with(
          error,
          hash_including(
            phone_number: '0123',
            template_id: CheckIn::Constants::OH_FAILURE_TEMPLATE_ID,
            claim_number: claim_number
          ),
          hash_including(error: :check_in_va_notify_job, team: 'check-in')
        )

        expect(StatsD).to receive(:increment).with(
          CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
          tags: CheckIn::Constants::STATSD_OH_SILENT_FAILURE_TAGS
        )

        expect(StatsD).to receive(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)

        described_class.sidekiq_retries_exhausted_block.call(job_hash, error)
      end

      it 'handles different facility types properly when retries are exhausted' do
        cie_job_opts = job_opts.merge(
          template_id: CheckIn::Constants::CIE_FAILURE_TEMPLATE_ID,
          facility_type: 'cie'
        )
        job_hash = { 'args' => [cie_job_opts] }
        error = StandardError.new('Test error')

        expect(StatsD).to receive(:increment).with(
          CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
          tags: CheckIn::Constants::STATSD_CIE_SILENT_FAILURE_TAGS
        )
        expect(StatsD).to receive(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)

        described_class.handle_error(job_hash, error)

        regular_job_opts = job_opts.merge(template_id: 'regular-template-id')
        job_hash = { 'args' => [regular_job_opts] }

        expect(StatsD).not_to receive(:increment).with(
          CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
          any_args
        )
        expect(StatsD).to receive(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)

        described_class.handle_error(job_hash, error)
      end
    end
  end

  describe 'phone number and date formatting' do
    let(:notify_client) { instance_double(VaNotify::Service) }

    before do
      allow(VaNotify::Service).to receive(:new).and_return(notify_client)
      allow(notify_client).to receive(:send_sms)
      allow(Settings.vanotify.services.check_in).to receive(:api_key).and_return('test-api-key')
    end

    it 'formats the appointment date and uses appropriate SMS sender ID based on facility type' do
      formatted_date = DateTime.strptime(appointment_date, '%Y-%m-%d').to_date.strftime('%b %d')

      # Test OH sender ID
      expect(notify_client).to receive(:send_sms).with(
        phone_number: mobile_phone,
        template_id:,
        sms_sender_id: CheckIn::Constants::OH_SMS_SENDER_ID,
        personalisation: { claim_number:, appt_date: formatted_date }
      )
      described_class.new.send(:va_notify_send_sms, job_opts)

      # Test CIE sender ID
      cie_opts = job_opts.merge(facility_type: 'cie')
      expect(notify_client).to receive(:send_sms).with(
        phone_number: mobile_phone,
        template_id:,
        sms_sender_id: CheckIn::Constants::CIE_SMS_SENDER_ID,
        personalisation: { claim_number:, appt_date: formatted_date }
      )
      described_class.new.send(:va_notify_send_sms, cie_opts)
    end
  end
end
