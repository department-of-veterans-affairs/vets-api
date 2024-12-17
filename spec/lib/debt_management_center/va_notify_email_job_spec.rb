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
      expect(StatsD).to receive(:increment).with(
        "#{DebtManagementCenter::VANotifyEmailJob::STATS_KEY}.retries_exhausted"
      )
      expect(Rails.logger).to receive(:error).with(expected_log_message)
      config.sidekiq_retries_exhausted_block.call('unused', exception)
    end
  end
end
