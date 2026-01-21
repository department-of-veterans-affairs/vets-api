# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DebtsApi::V0::Form5655Submission, type: :model do
  let(:user) { create(:user, :loa3) }
  let(:form5655_submission) { create(:debts_api_form5655_submission, user:, user_uuid: user.uuid) }
  let(:mock_log) { create(:debt_transaction_log, transactionable: form5655_submission) }

  before do
    allow(StatsD).to receive(:increment)
  end

  describe '#create_transaction_log_if_needed' do
    it 'calls DebtTransactionLog.track_waiver when no log exists' do
      allow(form5655_submission).to receive(:find_transaction_log).and_return(nil)
      expect(DebtTransactionLog).to receive(:track_waiver)
        .with(form5655_submission, anything)
        .and_return(mock_log)

      form5655_submission.send(:create_transaction_log_if_needed)
    end

    it 'returns existing log when one already exists' do
      allow(form5655_submission).to receive(:find_transaction_log).and_return(mock_log)

      result = form5655_submission.send(:create_transaction_log_if_needed)
      expect(result).to eq(mock_log)
    end
  end

  describe '#submit_to_vba' do
    it 'creates transaction log and marks as submitted' do
      allow(DebtsApi::V0::Form5655::VBASubmissionJob).to receive(:perform_async)
      allow(form5655_submission).to receive_messages(user_cache_id: 'cache123',
                                                     create_transaction_log_if_needed: mock_log)

      expect(mock_log).to receive(:mark_submitted)

      form5655_submission.submit_to_vba
    end
  end

  describe '#submit_to_vha' do
    it 'creates transaction log and marks as submitted' do
      allow(DebtsApi::V0::Form5655::VHA::VBSSubmissionJob).to receive(:perform_async)
      allow(DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob).to receive(:perform_in)
      allow(form5655_submission).to receive_messages(user_cache_id: 'cache123',
                                                     create_transaction_log_if_needed: mock_log)

      expect(mock_log).to receive(:mark_submitted)

      form5655_submission.submit_to_vha
    end
  end

  describe '#register_success' do
    it 'marks transaction log as completed' do
      allow(form5655_submission).to receive(:find_transaction_log).and_return(mock_log)
      expect(mock_log).to receive(:mark_completed)

      form5655_submission.register_success
    end
  end

  describe '#register_failure' do
    it 'marks transaction log as failed' do
      allow(form5655_submission).to receive(:find_transaction_log).and_return(mock_log)
      expect(mock_log).to receive(:mark_failed)

      form5655_submission.register_failure('Test error')
    end
  end
end
