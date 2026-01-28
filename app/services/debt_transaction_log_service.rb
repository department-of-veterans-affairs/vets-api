# frozen_string_literal: true

class DebtTransactionLogService
  STATS_KEY = 'api.debt_transaction_log'

  def self.track_dispute(submission, user)
    create_transaction_log(
      transactionable: submission,
      transaction_type: 'dispute',
      user_uuid: user.uuid,
      debt_identifiers: submission.debt_identifiers || [],
      summary_data: DebtTransactionLog::SummaryBuilders::DisputeSummaryBuilder.build(submission)
    )
  end

  def self.track_waiver(submission, user)
    create_transaction_log(
      transactionable: submission,
      transaction_type: 'waiver',
      user_uuid: user.uuid,
      debt_identifiers: extract_waiver_debt_identifiers(submission),
      summary_data: DebtTransactionLog::SummaryBuilders::WaiverSummaryBuilder.build(submission)
    )
  end

  def self.mark_submitted(transaction_log:, external_reference_id: nil)
    update_state(transaction_log, 'submitted', external_reference_id:)
  end

  def self.mark_completed(transaction_log:, external_reference_id: nil)
    update_state(transaction_log, 'completed', external_reference_id:, completed_at: Time.current)
  end

  def self.mark_failed(transaction_log:, external_reference_id: nil)
    update_state(transaction_log, 'failed', external_reference_id:, completed_at: Time.current)
  end

  class << self
    private

    def create_transaction_log(transactionable:, transaction_type:, user_uuid:, debt_identifiers:, summary_data:)
      attributes = build_transaction_log_attributes(
        transactionable:,
        transaction_type:,
        user_uuid:,
        debt_identifiers:,
        summary_data:
      )

      log = DebtTransactionLog.create!(attributes)

      StatsD.increment("#{STATS_KEY}.#{transaction_type}.created")
      log
    rescue => e
      Rails.logger.error("Failed to create #{transaction_type} transaction log: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      StatsD.increment("#{STATS_KEY}.#{transaction_type}.creation_failed")
      nil
    end

    def build_transaction_log_attributes(transactionable:, transaction_type:, user_uuid:, debt_identifiers:,
                                         summary_data:)
      {
        transactionable_type: transactionable.class.name,
        transactionable_id: resolve_transactionable_id(transactionable),
        transaction_type:,
        user_uuid:,
        debt_identifiers:,
        summary_data:,
        state: 'pending',
        transaction_started_at: Time.current
      }
    end

    def resolve_transactionable_id(transactionable)
      if transactionable.is_a?(DebtsApi::V0::DigitalDisputeSubmission)
        transactionable.guid
      else
        transactionable.id
      end
    end

    def update_state(transaction_log, new_state, external_reference_id: nil, completed_at: nil)
      return false unless transaction_log

      update_data = { state: new_state }
      update_data[:external_reference_id] = external_reference_id if external_reference_id
      update_data[:transaction_completed_at] = completed_at if completed_at

      transaction_log.update!(update_data)

      StatsD.increment("#{STATS_KEY}.#{transaction_log.transaction_type}.state.#{new_state}")
      true
    rescue => e
      Rails.logger.error("Failed to update debt transaction log state to #{new_state}: #{e.message}")
      StatsD.increment("#{STATS_KEY}.state_update_failed")
      false
    end

    def extract_waiver_debt_identifiers(submission)
      # Format: "#{deductionCode}#{originalAR.to_i}" for VBA debts, UUID for VHA copays
      submission.debt_identifiers
    rescue => e
      Rails.logger.warn("Failed to extract debt identifiers for waiver submission #{submission.id}: #{e.message}")
      []
    end
  end
end
