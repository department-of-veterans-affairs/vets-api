# frozen_string_literal: true

module AsyncTransaction
  module EVSS
    class VA526ezSubmitTransaction < AsyncTransaction::Base
      JOB_STATUS = {
        submitted: 'submitted',
        received: 'received',
        retrying: 'retrying',
        non_retryable_error: 'non_retryable_error',
        exhausted: 'exhausted'
      }.freeze
      SOURCE = 'EVSS'

      scope :for_user, ->(user) { where(user_uuid: user.uuid) }
      scope :job_id, ->(job_id) { where(transaction_id: job_id).limit(1) }

      def self.start(user, job_id)
        create!(
          user_uuid: user.uuid,
          source_id: user.edipi,
          source: SOURCE,
          status: REQUESTED,
          transaction_status: JOB_STATUS[:submitted],
          transaction_id: job_id
        )
      end

      def self.find_transaction(user, job_id)
        VA526ezSubmitTransaction.for_user(user).job_id(job_id).first
      end

      def self.find_transactions(user)
        VA526ezSubmitTransaction.for_user(user)
      end

      def self.update_transaction(user, job_id, status, response_body)
        raise ArgumentError, "#{status} is not a valid status" unless JOB_STATUS.keys.include?(status)
        transaction = VA526ezSubmitTransaction.find_transaction(user, job_id)
        transaction.update(
          status: COMPLETED,
          transaction_status: JOB_STATUS[status],
          metadata: response_body
        )
      end
    end
  end
end
