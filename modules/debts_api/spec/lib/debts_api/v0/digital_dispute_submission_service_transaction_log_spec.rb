# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/digital_dispute_submission_service'

RSpec.describe DebtsApi::V0::DigitalDisputeSubmissionService do
  let(:user) { create(:user, :loa3) }
  let(:files) { [fixture_file_upload('spec/fixtures/pdf_fill/686C-674-V2/tester.pdf', 'application/pdf')] }
  let(:metadata) { { disputes: [{ debt_id: 'debt123' }] } }
  let(:service) { described_class.new(user, files, metadata) }

  before do
    allow(StatsD).to receive(:increment)
    allow(service).to receive(:send_to_dmc)
    allow(service).to receive(:send_submission_email)
    allow(DebtTransactionLog::SummaryBuilders::DisputeSummaryBuilder).to receive(:build).and_return({})
  end

  describe '#call' do
    it 'creates transaction log for dispute' do
      expect(DebtTransactionLog).to receive(:track_dispute)
        .with(anything, user)
        .and_return(double('log', mark_submitted: true, mark_completed: true))

      service.call
    end

    it 'marks transaction log as submitted during processing' do
      mock_log = double('log', mark_submitted: true, mark_completed: true)
      allow(DebtTransactionLog).to receive(:track_dispute).and_return(mock_log)

      expect(mock_log).to receive(:mark_submitted)

      service.call
    end

    it 'marks transaction log as completed on success' do
      mock_log = double('log', mark_submitted: true, mark_completed: true)
      allow(DebtTransactionLog).to receive(:track_dispute).and_return(mock_log)

      expect(mock_log).to receive(:mark_completed)

      service.call
    end

    context 'when processing fails' do
      before do
        allow(service).to receive(:send_to_dmc).and_raise(StandardError, 'API error')
      end

      it 'marks transaction log as failed' do
        mock_log = double('log', mark_submitted: true, mark_failed: true)
        allow(DebtTransactionLog).to receive(:track_dispute).and_return(mock_log)

        expect(mock_log).to receive(:mark_failed)

        service.call
      end

      it 'returns failure result' do
        allow(DebtTransactionLog).to receive(:track_dispute).and_return(double('log', mark_failed: true))

        result = service.call

        expect(result[:success]).to be false
      end
    end

    context 'when duplicate submission detected' do
      before do
        allow(service).to receive(:check_duplicate?).and_return(true)
      end

      it 'does not update transaction log to submitted or completed' do
        mock_log = double('log')
        allow(DebtTransactionLog).to receive(:track_dispute).and_return(mock_log)

        expect(mock_log).not_to receive(:mark_submitted)
        expect(mock_log).not_to receive(:mark_completed)

        service.call
      end
    end
  end
end
