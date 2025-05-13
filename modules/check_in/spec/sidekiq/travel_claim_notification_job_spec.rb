# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::TravelClaimNotificationJob do
  let(:mobile_phone) { '202-555-0123' }
  let(:appointment_date) { '2023-05-15' }
  let(:claim_number) { '1234' }
  let(:facility_type) { 'oh' }
  let(:template_id) { 'template-id-123' }
  let(:formatted_date) { DateTime.strptime(appointment_date, '%Y-%m-%d').to_date.strftime('%b %d') }
  let(:parsed_date) { DateTime.strptime(appointment_date, '%Y-%m-%d').to_date }
  let(:job_opts) do
    {
      mobile_phone:,
      appointment_date:,
      template_id:,
      claim_number:,
      facility_type:
    }
  end
  let(:notify_client) { instance_double(VaNotify::Service) }
  let(:test_logger) { instance_double(Logger) }

  before do
    allow(VaNotify::Service).to receive(:new).and_return(notify_client)
    allow(notify_client).to receive(:send_sms)
    allow_any_instance_of(described_class).to receive(:logger).and_return(test_logger)
    allow(test_logger).to receive(:info)
    allow(Settings.vanotify.services.check_in).to receive(:api_key).and_return('test-api-key')
    allow(StatsD).to receive(:increment)
  end

  describe '#perform' do
    it 'successfully sends SMS notification via VaNotify service' do
      expect(notify_client).to receive(:send_sms).with(
        phone_number: mobile_phone,
        template_id:,
        sms_sender_id: CheckIn::Constants::OH_SMS_SENDER_ID,
        personalisation: { claim_number:, appt_date: formatted_date }
      )

      described_class.new.perform(job_opts)

      expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_SUCCESS)
    end

    it 'skips SMS sending and logs when mobile phone is missing' do
      job_opts.delete(:mobile_phone)
      job = described_class.new

      expect(notify_client).not_to receive(:send_sms)
      expect(StatsD).to receive(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
      expect(test_logger).to receive(:info).with(
        hash_including(message: 'TravelClaimNotificationJob failed without retry: missing mobile_phone')
      )

      job.perform(job_opts)
    end

    it 'successfully sends SMS even when claim number is missing' do
      job_opts.delete(:claim_number)
      job = described_class.new

      expect(notify_client).to receive(:send_sms).with(
        phone_number: mobile_phone,
        template_id:,
        sms_sender_id: CheckIn::Constants::OH_SMS_SENDER_ID,
        personalisation: { claim_number: nil, appt_date: formatted_date }
      )

      job.perform(job_opts)

      expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_SUCCESS)
    end

    it 'skips SMS sending and logs when appointment date is invalid' do
      job_opts[:appointment_date] = 'invalid-date'
      job = described_class.new

      expect(notify_client).not_to receive(:send_sms)
      expect(StatsD).to receive(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
      expect(test_logger).to receive(:info).with(
        hash_including(message: 'TravelClaimNotificationJob failed without retry: invalid appointment date format')
      )

      job.perform(job_opts)
    end

    context 'when an error occurs during SMS sending' do
      before do
        allow(notify_client).to receive(:send_sms).and_raise(StandardError.new('Test error'))
      end

      it 'logs failures and raises the error' do
        job = described_class.new

        expect(test_logger).to receive(:info)
          .with(hash_including(message: 'Sending travel claim notification to 0123, template-id-123'))
        expect(test_logger).to receive(:info)
          .with(hash_including(
                  message: "TravelClaimNotificationJob failed"
                ))

        expect { job.perform(job_opts) }.to raise_error(StandardError)
      end
    end
  end

  describe 'retry configuration' do
    it 'has MAX_RETRIES matching sidekiq_options retry setting' do
      sidekiq_retry_value = described_class.sidekiq_options_hash['retry']
      expect(described_class::MAX_RETRIES).to eq(sidekiq_retry_value)
    end
  end

  describe '.phone_last_four' do
    it 'returns last four digits of a phone number' do
      hash = { mobile_phone: '202-555-0123' }
      expect(described_class.phone_last_four(hash)).to eq('0123')
    end

    it 'handles non-numeric characters in phone number' do
      hash = { mobile_phone: '(202) 555-0123' }
      expect(described_class.phone_last_four(hash)).to eq('0123')
    end

    it 'returns nil when mobile_phone is missing' do
      hash = { other_key: 'value' }
      expect(described_class.phone_last_four(hash)).to be_nil
    end

    it 'returns nil when hash is nil' do
      expect(described_class.phone_last_four(nil)).to be_nil
    end
  end

  describe 'error handling and facility type handling' do
    let(:error) { StandardError.new('Test error') }

    it 'handles errors correctly when retries are exhausted with OH facility' do
      oh_job_opts = job_opts.merge(template_id: CheckIn::Constants::OH_FAILURE_TEMPLATE_ID)
      job_hash = { 'args' => [oh_job_opts], 'error_message' => 'Test error' }

      expect(SentryLogging).to receive(:log_exception_to_sentry).with(
        error,
        hash_including(
          phone_number: '0123',
          template_id: CheckIn::Constants::OH_FAILURE_TEMPLATE_ID,
          claim_number:
        ),
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
      cie_job_opts = job_opts.merge(
        template_id: CheckIn::Constants::CIE_FAILURE_TEMPLATE_ID,
        facility_type: 'cie'
      )
      job_hash = { 'args' => [cie_job_opts] }

      described_class.handle_error(job_hash, error)

      expect(StatsD).to have_received(:increment).with(
        CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
        tags: CheckIn::Constants::STATSD_CIE_SILENT_FAILURE_TAGS
      )
      expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
    end

    it 'handles errors correctly with regular templates' do
      regular_job_opts = job_opts.merge(template_id: 'regular-template-id')
      job_hash = { 'args' => [regular_job_opts] }

      described_class.handle_error(job_hash, error)

      expect(StatsD).not_to have_received(:increment).with(
        CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
        any_args
      )
      expect(StatsD).to have_received(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
    end
  end

  describe 'SMS sender ID selection' do
    it 'uses appropriate SMS sender ID based on facility type' do
      # Test OH sender ID
      expect(notify_client).to receive(:send_sms).with(
        phone_number: mobile_phone,
        template_id:,
        sms_sender_id: CheckIn::Constants::OH_SMS_SENDER_ID,
        personalisation: { claim_number:, appt_date: formatted_date }
      )
      described_class.new.send(:va_notify_send_sms,
                               phone_number: mobile_phone,
                               template_id:,
                               claim_number:,
                               facility_type: 'oh',
                               parsed_date:)

      # Test CIE sender ID
      expect(notify_client).to receive(:send_sms).with(
        phone_number: mobile_phone,
        template_id:,
        sms_sender_id: CheckIn::Constants::CIE_SMS_SENDER_ID,
        personalisation: { claim_number:, appt_date: formatted_date }
      )
      described_class.new.send(:va_notify_send_sms,
                               phone_number: mobile_phone,
                               template_id:,
                               claim_number:,
                               facility_type: 'cie',
                               parsed_date:)
    end
  end
end
