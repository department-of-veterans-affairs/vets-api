# frozen_string_literal: true

class DebtTransactionLog < ApplicationRecord
  belongs_to :transactionable, polymorphic: true, optional: true

  # Override setter to use guid for DigitalDisputeSubmission
  def transactionable=(record)
    if record.is_a?(DebtsApi::V0::DigitalDisputeSubmission)
      self.transactionable_type = record.class.name
      self.transactionable_id = record.guid
    else
      super
    end
  end

  # Override getter to find by guid for DigitalDisputeSubmission
  def transactionable
    return super unless transactionable_type == 'DebtsApi::V0::DigitalDisputeSubmission'

    DebtsApi::V0::DigitalDisputeSubmission.find_by(guid: transactionable_id)
  end

  enum :state, pending: 'pending', submitted: 'submitted', completed: 'completed', failed: 'failed'

  validates :transaction_type, presence: true, inclusion: { in: %w[dispute payment waiver] }
  validates :user_uuid, presence: true
  validates :debt_identifiers, presence: true
  validates :transaction_started_at, presence: true
  validates :state, presence: true

  def self.track_dispute(submission, user)
    DebtTransactionLogService.track_dispute(submission, user)
  end

  def self.track_waiver(submission, user)
    DebtTransactionLogService.track_waiver(submission, user)
  end

  def mark_submitted(external_reference_id: nil)
    DebtTransactionLogService.mark_submitted(transaction_log: self, external_reference_id:)
  end

  def mark_completed(external_reference_id: nil)
    DebtTransactionLogService.mark_completed(transaction_log: self, external_reference_id:)
  end

  def mark_failed(external_reference_id: nil)
    DebtTransactionLogService.mark_failed(transaction_log: self, external_reference_id:)
  end
end
