# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DebtTransactionLogService do
  let(:user) { create(:user) }
  let(:form5655_submission) { create(:debts_api_form5655_submission, user_uuid: user.uuid) }
  let(:digital_dispute_submission) { create(:debts_api_digital_dispute_submission, user_uuid: user.uuid) }

  before do
    allow(StatsD).to receive(:increment)
    allow(DebtTransactionLog::SummaryBuilders::DisputeSummaryBuilder).to receive(:build).and_return({})
    allow(DebtTransactionLog::SummaryBuilders::WaiverSummaryBuilder).to receive(:build).and_return({})
  end

  describe '.track_dispute' do
    before do
      allow(digital_dispute_submission).to receive(:debt_identifiers).and_return(%w[debt123 debt456])
    end

    it 'creates a transaction log with correct attributes' do
      log = DebtTransactionLogService.track_dispute(digital_dispute_submission, user)

      expect(log).to be_persisted
      expect(log.transactionable).to eq(digital_dispute_submission)
      expect(log.transaction_type).to eq('dispute')
      expect(log.user_uuid).to eq(user.uuid)
      expect(log.debt_identifiers).to eq(%w[debt123 debt456])
      expect(log.state).to eq('pending')
    end

    it 'fires StatsD metrics on create' do
      DebtTransactionLogService.track_dispute(digital_dispute_submission, user)
      expect(StatsD).to have_received(:increment).with('api.debt_transaction_log.dispute.created')
    end

    it 'returns nil on creation failure' do
      allow(DebtTransactionLog).to receive(:create!).and_raise(StandardError, 'DB error')

      log = DebtTransactionLogService.track_dispute(digital_dispute_submission, user)

      expect(log).to be_nil
      expect(StatsD).to have_received(:increment).with('api.debt_transaction_log.dispute.creation_failed')
    end
  end

  describe '.track_waiver' do
    before do
      allow(form5655_submission).to receive(:debt_identifiers).and_return(['waiver123'])
    end

    it 'creates a transaction log with correct attributes' do
      log = DebtTransactionLogService.track_waiver(form5655_submission, user)

      expect(log).to be_persisted
      expect(log.transactionable).to eq(form5655_submission)
      expect(log.transaction_type).to eq('waiver')
      expect(log.user_uuid).to eq(user.uuid)
      expect(log.debt_identifiers).to eq(['waiver123'])
      expect(log.state).to eq('pending')
    end

    it 'fires StatsD metrics on create' do
      DebtTransactionLogService.track_waiver(form5655_submission, user)
      expect(StatsD).to have_received(:increment).with('api.debt_transaction_log.waiver.created')
    end

    it 'returns nil on creation failure' do
      allow(DebtTransactionLog).to receive(:create!).and_raise(StandardError, 'DB error')

      log = DebtTransactionLogService.track_waiver(form5655_submission, user)

      expect(log).to be_nil
      expect(StatsD).to have_received(:increment).with('api.debt_transaction_log.waiver.creation_failed')
    end
  end

  describe '.mark_submitted' do
    let(:log) { create(:debt_transaction_log, transactionable: form5655_submission, state: 'pending') }

    it 'updates state to submitted' do
      result = DebtTransactionLogService.mark_submitted(transaction_log: log)

      expect(result).to be true
      expect(log.reload.state).to eq('submitted')
    end

    it 'updates external_reference_id when provided' do
      DebtTransactionLogService.mark_submitted(transaction_log: log, external_reference_id: 'ref123')

      expect(log.reload.external_reference_id).to eq('ref123')
    end

    it 'fires StatsD metrics on state change' do
      DebtTransactionLogService.mark_submitted(transaction_log: log)
      expect(StatsD).to have_received(:increment).with('api.debt_transaction_log.waiver.state.submitted')
    end

    it 'returns false when log is nil' do
      result = DebtTransactionLogService.mark_submitted(transaction_log: nil)
      expect(result).to be false
    end
  end

  describe '.mark_completed' do
    let(:log) { create(:debt_transaction_log, transactionable: form5655_submission, state: 'submitted') }

    it 'updates state to completed' do
      result = DebtTransactionLogService.mark_completed(transaction_log: log)

      expect(result).to be true
      expect(log.reload.state).to eq('completed')
      expect(log.transaction_completed_at).to be_present
    end

    it 'fires StatsD metrics on state change' do
      DebtTransactionLogService.mark_completed(transaction_log: log)
      expect(StatsD).to have_received(:increment).with('api.debt_transaction_log.waiver.state.completed')
    end
  end

  describe '.mark_failed' do
    let(:log) { create(:debt_transaction_log, transactionable: form5655_submission, state: 'submitted') }

    it 'updates state to failed' do
      result = DebtTransactionLogService.mark_failed(transaction_log: log)

      expect(result).to be true
      expect(log.reload.state).to eq('failed')
      expect(log.transaction_completed_at).to be_present
    end

    it 'fires StatsD metrics on state change' do
      DebtTransactionLogService.mark_failed(transaction_log: log)
      expect(StatsD).to have_received(:increment).with('api.debt_transaction_log.waiver.state.failed')
    end

    it 'returns false on update failure' do
      allow(log).to receive(:update!).and_raise(StandardError, 'DB error')

      result = DebtTransactionLogService.mark_failed(transaction_log: log)

      expect(result).to be false
      expect(StatsD).to have_received(:increment).with('api.debt_transaction_log.state_update_failed')
    end
  end
end
