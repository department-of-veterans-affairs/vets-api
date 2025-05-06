# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/statement_identifier_service'
require 'debt_management_center/sidekiq/va_notify_email_job'

RSpec.describe CopayNotifications::NewStatementNotificationJob, type: :worker do
  before do
    Sidekiq::Job.clear_all
  end

  describe '#perform' do
    let(:statement) do
      {
        'veteranIdentifier' => '492031291',
        'identifierType' => 'edipi',
        'facilityNum' => '123',
        'facilityName' => 'VA Medical Center',
        'statementDate' => '01/01/2023'
      }
    end
    let(:personalisation) do
      {
        'icn' => '1234',
        'first_name' => 'Guy'
      }
    end

    before do
      allow_any_instance_of(DebtManagementCenter::StatementIdentifierService)
        .to receive(:get_mpi_data).and_return(personalisation)
    end

    it 'sends a new mcp notification email job frome edipi' do
      job = described_class.new

      # pausing until further notice
      expect { job.perform(statement) }
        .not_to change { DebtManagementCenter::VANotifyEmailJob.jobs.size }
        .from(0)
      # expect { job.perform(statement) }
      #   .to change { DebtManagementCenter::VANotifyEmailJob.jobs.size }
      #   .from(0)
      #   .to(1)
    end

    context 'veteran identifier is a vista id' do
      let(:icn) { '1234' }
      let(:statement) do
        {
          'veteranIdentifier' => '348530923',
          'identifierType' => 'dfn',
          'facilityNum' => '456',
          'facilityName' => 'VA Medical Center',
          'statementDate' => '01/01/2023'
        }
      end

      it 'sends a new mcp notification email job frome facility and vista id' do
        job = described_class.new

        # pausing until further notice
        expect { job.perform(statement) }
          .not_to change { DebtManagementCenter::VANotifyEmailJob.jobs.size }
          .from(0)
        # expect { job.perform(statement) }
        #   .to change { DebtManagementCenter::VANotifyEmailJob.jobs.size }
        #   .from(0)
        #   .to(1)
      end
    end

    context 'with malformed statement' do
      let(:statement) do
        {
          'identifierType' => 'dfn',
          'facilityName' => 'VA Medical Center',
          'statementDate' => '01/01/2023'
        }
      end

      it 'throws an error' do
        job = described_class.new
        expect { job.perform(statement) }.to raise_error do |error|
          expect(error).to be_instance_of(DebtManagementCenter::StatementIdentifierService::MalformedMCPStatement)
        end
      end
    end

    context 'with retryable error' do
      subject(:config) { described_class }

      let(:error) { OpenStruct.new(message: 'oh shoot') }
      let(:exception) { DebtManagementCenter::StatementIdentifierService::RetryableError.new(error) }

      it 'sends job to retry queue' do
        expect(config.sidekiq_retry_in_block.call(0, exception, nil)).to eq(10)
      end
    end

    context 'with retries exhausted' do
      subject(:config) { described_class }

      let(:error) { OpenStruct.new(message: 'oh shoot') }
      let(:exception) do
        e = DebtManagementCenter::StatementIdentifierService::RetryableError.new(error)
        allow(e).to receive(:backtrace).and_return(['line 1', 'line 2', 'line 3'])
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
          NewStatementNotificationJob retries exhausted:
          Exception: #{exception.class} - #{exception.message}
          Backtrace: #{exception.backtrace.join("\n")}
        LOG

        statsd_key = CopayNotifications::NewStatementNotificationJob::STATSD_KEY_PREFIX
        ["#{statsd_key}.failure", "#{statsd_key}.retries_exhausted"].each do |key|
          expect(StatsD).to receive(:increment).with(key)
        end
        expect(Rails.logger).to receive(:error).with(expected_log_message)
        config.sidekiq_retries_exhausted_block.call(msg, exception)
      end
    end

    context 'with any other error' do
      subject(:config) { described_class }

      let(:exception) { DebtManagementCenter::StatementIdentifierService::MalformedMCPStatement.new(nil) }

      it 'kills the job' do
        expect(config.sidekiq_retry_in_block.call(0, exception, nil)).to eq(:kill)
      end
    end
  end
end
