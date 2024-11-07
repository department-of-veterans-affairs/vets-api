# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CopayNotifications::ParseNewStatementsJob, type: :worker do
  before do
    Sidekiq::Job.clear_all
  end

  describe '#perform' do
    let(:statements_json_byte) { Base64.encode64(File.read('spec/fixtures/medical_copays/new_statements.json')) }

    it 'parses and creates individual new statement jobs' do
      job = described_class.new
      expect { job.perform(statements_json_byte) }
        .to change { CopayNotifications::NewStatementNotificationJob.jobs.size }
        .from(0)
        .to(2)
    end

    context 'duplicate identifiers' do
      let(:statements_json_byte) do
        Base64.encode64(File.read('spec/fixtures/medical_copays/duplicate_new_statements.json'))
      end

      it 'only creates a single job for duplicate identifiers' do
        job = described_class.new
        expect { job.perform(statements_json_byte) }
          .to change { CopayNotifications::NewStatementNotificationJob.jobs.size }
          .from(0)
          .to(1)
      end
    end

    context 'batch processing' do
      let(:statements_json_byte) do
        Base64.encode64(File.read('spec/fixtures/medical_copays/new_statements.json'))
      end
      let(:job_interval) { Settings.mcp.notifications.job_interval }

      before do
        stub_const('CopayNotifications::ParseNewStatementsJob::BATCH_SIZE', 1)
      end

      it 'starts the jobs at different times' do
        job = described_class.new
        statement_json = Oj.load(Base64.decode64(statements_json_byte))
        first_statement = statement_json[0]
        expect(CopayNotifications::NewStatementNotificationJob).to receive(:perform_in).with(0, first_statement)

        second_statement = statement_json[1]
        expect(CopayNotifications::NewStatementNotificationJob).to receive(:perform_in).with(job_interval,
                                                                                             second_statement)
        job.perform(statements_json_byte)
      end
    end

    context 'with retries exhausted' do
      let(:config) { described_class }
      let(:exception) do
        e = StandardError.new('Test error')
        allow(e).to receive(:backtrace).and_return(%w[backtrace1 backtrace2])
        e
      end
      let(:msg) do
        {
          'class' => 'YourJobClassName',
          'args' => [statement],
          'jid' => '12345abcde',
          'retry_count' => 5
        }
      end

      it 'logs the error' do
        expected_log_message = <<~LOG
          CopayNotifications::ParseNewStatementsJob retries exhausted:
          Exception: #{exception.class} - #{exception.message}
          Backtrace: #{exception.backtrace.join("\n")}
        LOG

        expect(StatsD).to receive(:increment).with(
          "#{CopayNotifications::ParseNewStatementsJob::STATSD_KEY_PREFIX}.retries_exhausted"
        )

        expect(Rails.logger).to receive(:error).with(expected_log_message)
        config.sidekiq_retries_exhausted_block.call(statements_json_byte, exception)
      end
    end
  end
end
