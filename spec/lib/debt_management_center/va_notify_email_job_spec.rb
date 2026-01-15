# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require 'debt_management_center/sidekiq/va_notify_email_job'

RSpec.describe DebtManagementCenter::VANotifyEmailJob, type: :worker do
  describe '#perform' do
    it 'deletes the cache key after sending email' do
      cache_key = 'test_cache_key'
      va_notify_client = instance_double(VaNotify::Service)
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_client)
      allow(va_notify_client).to receive(:send_email)
      allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return({ email: 'test@example.com' })

      expect(Sidekiq::AttrPackage).to receive(:delete).with(cache_key)

      described_class.new.perform(nil, 'template_id', nil, { 'cache_key' => cache_key })
    end
  end

  context 'with retries exhausted' do
    subject(:config) { described_class }

    let(:error) { OpenStruct.new(message: 'oh shoot') }
    let(:exception) do
      e = StandardError.new(error)
      allow(e).to receive(:backtrace).and_return(['line 1', 'line 2', 'line 3'])
      e
    end

    it 'logs the error' do
      expected_log_message = <<~LOG
        VANotifyEmailJob retries exhausted:
        Exception: #{exception.class} - #{exception.message}
        Backtrace: #{exception.backtrace.join("\n")}
      LOG
      job = { 'args' => [nil, nil, nil, {}] }

      expect(StatsD).to receive(:increment).with(
        "#{DebtManagementCenter::VANotifyEmailJob::STATS_KEY}.retries_exhausted"
      )
      expect(StatsD).not_to receive(:increment).with(
        "#{DebtsApi::V0::Form5655Submission::STATS_KEY}.send_failed_form_email.failure"
      )
      expect(Rails.logger).to receive(:error).with(expected_log_message)
      config.sidekiq_retries_exhausted_block.call(job, exception)
    end

    it 'deletes redis cache_key when retries expire' do
      cache_key = 'test_cache_key_123'
      job = { 'args' => [nil, nil, nil, { 'cache_key' => cache_key }] }

      expect(Sidekiq::AttrPackage).to receive(:delete).with(cache_key)
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:error)

      config.sidekiq_retries_exhausted_block.call(job, exception)
    end

    context 'when firing a silent error email' do
      let(:email) { 'test@tester.com' }
      let(:template_id) { DebtsApi::V0::Form5655Submission::SUBMISSION_FAILURE_EMAIL_TEMPLATE_ID }
      let(:job_args) { [email, template_id, nil, { 'failure_mailer' => true }] }
      let(:call_back_metadata) do
        {
          callback_metadata: {
            notification_type: 'error',
            form_number: '5655',
            statsd_tags: { service: 'debt-resolution', function: 'register_failure' }
          }
        }
      end
      let(:personalisation) do
        {
          'first_name' => 'Homer',
          'date_submitted' => Time.zone.now.strftime('%m/%d/%Y'),
          'updated_at' => Time.zone.now.strftime('%m/%d/%Y'),
          'confirmation_number' => 'e7b5d0e3-2a6f-4b5b-91a5-0cc3d801f1e1'
        }
      end

      it 'increments the failure counter' do
        expect(StatsD).to receive(:increment).with(
          'silent_failure', tags: %w[service:debt-resolution function:sidekiq_retries_exhausted]
        )

        expect(StatsD).to receive(:increment).with('api.dmc.va_notify_email.retries_exhausted')
        expect(StatsD).to receive(:increment).with(
          "#{DebtsApi::V0::Form5655Submission::STATS_KEY}.send_failed_form_email.failure"
        )

        described_class.sidekiq_retries_exhausted_block.call({ 'args' => job_args }, exception)
      end

      it 'uses the callback options' do
        va_notify_client = instance_double(VaNotify::Service)
        allow(va_notify_client).to receive(:send_email)
        expect(VaNotify::Service).to receive(:new).with(
          Settings.vanotify.services.dmc.api_key,
          call_back_metadata
        ) { va_notify_client }
        config.new.perform(
          email,
          template_id,
          personalisation,
          { 'id_type' => 'email', 'failure_mailer' => true }
        )
      end

      it 'does not use the callback options' do
        va_notify_client = instance_double(VaNotify::Service)
        allow(va_notify_client).to receive(:send_email)
        expect(VaNotify::Service).to receive(:new).with(
          Settings.vanotify.services.dmc.api_key
        ) { va_notify_client }
        config.new.perform(
          email,
          template_id,
          personalisation
        )
      end
    end
  end
end
