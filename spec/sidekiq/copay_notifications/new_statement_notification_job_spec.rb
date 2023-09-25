# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/statement_identifier_service'
require 'debt_management_center/workers/va_notify_email_job'

RSpec.describe CopayNotifications::NewStatementNotificationJob, type: :worker do
  before do
    Sidekiq::Worker.clear_all
  end

  describe '#perform' do
    let(:icn) { '1234' }
    let(:statement) do
      {
        'veteranIdentifier' => '492031291',
        'identifierType' => 'edipi',
        'facilityNum' => '123',
        'facilityName' => 'VA Medical Center',
        'statementDate' => '01/01/2023'
      }
    end

    before do
      allow_any_instance_of(DebtManagementCenter::StatementIdentifierService)
        .to receive(:get_icn).and_return(icn)
    end

    it 'sends a new mcp notification email job frome edipi' do
      job = described_class.new
      expect { job.perform(statement) }
        .to change { DebtManagementCenter::VANotifyEmailJob.jobs.size }
        .from(0)
        .to(1)
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

      before do
        allow_any_instance_of(DebtManagementCenter::StatementIdentifierService)
          .to receive(:get_icn).and_return(icn)
      end

      it 'sends a new mcp notification email job frome facility and vista id' do
        job = described_class.new
        expect { job.perform(statement) }
          .to change { DebtManagementCenter::VANotifyEmailJob.jobs.size }
          .from(0)
          .to(1)
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

    context 'with any other error' do
      subject(:config) { described_class }

      let(:exception) { DebtManagementCenter::StatementIdentifierService::MalformedMCPStatement.new(nil) }

      it 'kills the job' do
        expect(config.sidekiq_retry_in_block.call(0, exception, nil)).to eq(:kill)
      end
    end
  end
end
