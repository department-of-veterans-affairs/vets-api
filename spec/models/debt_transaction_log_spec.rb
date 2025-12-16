# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DebtTransactionLog, type: :model do
  let(:user) { create(:user) }
  let(:form5655_submission) { create(:debts_api_form5655_submission, user_uuid: user.uuid) }
  let(:digital_dispute_submission) { create(:debts_api_digital_dispute_submission, user_uuid: user.uuid) }

  describe 'validations' do
    it 'validates required fields' do
      log = DebtTransactionLog.new
      expect(log).not_to be_valid
      expect(log.errors[:transaction_type]).to include("can't be blank")
      expect(log.errors[:user_uuid]).to include("can't be blank")
      expect(log.errors[:debt_identifiers]).to include("can't be blank")
      expect(log.errors[:state]).to include("can't be blank")
    end

    it 'validates transaction_type inclusion' do
      log = build(:debt_transaction_log, transaction_type: 'invalid')
      expect(log).not_to be_valid
      expect(log.errors[:transaction_type]).to include('is not included in the list')
    end

    it 'creates a valid transaction log with required attributes' do
      log = build(:debt_transaction_log,
                  transaction_type: 'waiver',
                  user_uuid: user.uuid,
                  debt_identifiers: ['debt123'],
                  state: 'pending',
                  transactionable: form5655_submission)
      expect(log).to be_valid
    end
  end

  describe 'state enum' do
    let(:log) { create(:debt_transaction_log, transactionable: form5655_submission) }

    it 'has correct state transitions' do
      expect(log.pending?).to be true

      log.submitted!
      expect(log.submitted?).to be true

      log.completed!
      expect(log.completed?).to be true
    end

    it 'can transition to failed state' do
      log.failed!
      expect(log.failed?).to be true
    end
  end

  describe 'polymorphic associations' do
    it 'works with Form5655Submission' do
      log = create(:debt_transaction_log, transactionable: form5655_submission)
      expect(log.transactionable).to eq(form5655_submission)
      expect(log.transactionable_type).to eq('DebtsApi::V0::Form5655Submission')
    end

    it 'works with DigitalDisputeSubmission' do
      log = create(:debt_transaction_log,
                   transactionable_type: 'DebtsApi::V0::DigitalDisputeSubmission',
                   transactionable_id: digital_dispute_submission.guid)
      expect(log.transactionable).to eq(digital_dispute_submission)
      expect(log.transactionable_type).to eq('DebtsApi::V0::DigitalDisputeSubmission')
    end
  end

  describe 'class methods' do
    it 'delegates track_dispute to service' do
      expect(DebtTransactionLogService).to receive(:track_dispute)
        .with(digital_dispute_submission, user)
      DebtTransactionLog.track_dispute(digital_dispute_submission, user)
    end

    it 'delegates track_waiver to service' do
      expect(DebtTransactionLogService).to receive(:track_waiver)
        .with(form5655_submission, user)
      DebtTransactionLog.track_waiver(form5655_submission, user)
    end
  end

  describe 'instance methods' do
    let(:log) { create(:debt_transaction_log, transactionable: form5655_submission) }

    it 'delegates mark_submitted to service' do
      expect(DebtTransactionLogService).to receive(:mark_submitted)
        .with(transaction_log: log, external_reference_id: 'ref123')
      log.mark_submitted(external_reference_id: 'ref123')
    end

    it 'delegates mark_completed to service' do
      expect(DebtTransactionLogService).to receive(:mark_completed)
        .with(transaction_log: log, external_reference_id: nil)
      log.mark_completed
    end

    it 'delegates mark_failed to service' do
      expect(DebtTransactionLogService).to receive(:mark_failed)
        .with(transaction_log: log, external_reference_id: nil)
      log.mark_failed
    end
  end
end
