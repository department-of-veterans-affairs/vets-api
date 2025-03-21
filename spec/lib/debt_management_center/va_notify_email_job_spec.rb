# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require 'debt_management_center/sidekiq/va_notify_email_job'

RSpec.describe DebtManagementCenter::VANotifyEmailJob, type: :worker do
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

    context 'when firing a silent error email' do
      let(:email) { 'test@tester.com' }
      let(:template_id) { '123-abc' }
      let(:job_args) { [email, template_id, nil, { 'failure_mailer' => true }] }

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
    end
  end
end
