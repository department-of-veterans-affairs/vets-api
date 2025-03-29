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
      mobile_phone: mobile_phone,
      appointment_date: appointment_date,
      template_id: template_id,
      claim_number: claim_number,
      facility_type: facility_type
    }
  end

  describe '#send_notification' do
    subject { described_class.new.send_notification(job_opts) }

    before do
      allow_any_instance_of(VaNotify::Service).to receive(:send_sms)
      allow_any_instance_of(described_class).to receive(:logger).and_return(Logger.new(nil))
    end

    it 'logs the notification and sends SMS' do
      expect_any_instance_of(described_class).to receive(:log_sending_travel_claim_notification).with(job_opts)
      expect_any_instance_of(described_class).to receive(:va_notify_send_sms).with(job_opts)
      subject
    end

    context 'when an error occurs' do
      before do
        allow_any_instance_of(described_class).to receive(:va_notify_send_sms).and_raise(StandardError.new('Test error'))
      end

      it 'logs the failure and raises the error' do
        expect_any_instance_of(described_class).to receive(:log_send_sms_failure)
        expect { subject }.to raise_error(StandardError, 'Test error')
      end
    end

    context 'when it exhausts retries' do
      before do
        allow_any_instance_of(described_class).to receive(:va_notify_send_sms).and_raise(StandardError.new('Test error'))
      end

      it 'tracks the failure' do
        job_hash = { 'args' => [job_opts] }
        CheckIn::TravelClaimBaseJob.within_sidekiq_retries_exhausted_block(job_hash) do
          expect(StatsD).to receive(:increment).with(CheckIn::Constants::STATSD_NOTIFY_ERROR)
        end
      end
    end
  end

  describe '#va_notify_send_sms' do
    let(:notify_client) { instance_double(VaNotify::Service) }

    before do
      allow(VaNotify::Service).to receive(:new).and_return(notify_client)
      allow(notify_client).to receive(:send_sms)
      allow(Settings.vanotify.services.check_in).to receive(:api_key).and_return('test-api-key')
    end

    it 'formats the appointment date and sends SMS with OH sender ID' do
      formatted_date = DateTime.strptime(appointment_date, '%Y-%m-%d').to_date.strftime('%b %d')

      expect(notify_client).to receive(:send_sms).with(
        phone_number: mobile_phone,
        template_id: template_id,
        sms_sender_id: CheckIn::Constants::OH_SMS_SENDER_ID,
        personalisation: { claim_number: claim_number, appt_date: formatted_date }
      )

      described_class.new.send(:va_notify_send_sms, job_opts)
    end

    context 'with CIE facility type' do
      let(:facility_type) { 'cie' }

      it 'sends SMS with CIE sender ID' do
        formatted_date = DateTime.strptime(appointment_date, '%Y-%m-%d').to_date.strftime('%b %d')

        expect(notify_client).to receive(:send_sms).with(
          phone_number: mobile_phone,
          template_id: template_id,
          sms_sender_id: CheckIn::Constants::CIE_SMS_SENDER_ID,
          personalisation: { claim_number: claim_number, appt_date: formatted_date }
        )

        described_class.new.send(:va_notify_send_sms, job_opts)
      end
    end
  end
end