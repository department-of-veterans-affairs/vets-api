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

      # Creates an initial AsyncTransaction record for ongoing tracking and
      # set its transaction_status to submitted
      #
      # @param user [User] The user associated with the transaction
      # @param job_id [String] A sidekiq job id (uuid)
      # @return [AsyncTransaction::EVSS::VA526ezSubmitTransaction] the transaction
      #
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

      # Finds a single transaction by job_id
      #
      # @param job_id [String] A sidekiq job id (uuid)
      # @return [AsyncTransaction::EVSS::VA526ezSubmitTransaction] the transaction
      #
      def self.find_transaction(job_id)
        VA526ezSubmitTransaction.job_id(job_id).first
      end

      # Finds a single transaction by job_id
      #
      # @param user [User] The user associated with the transaction
      # @return [Array AsyncTransaction::EVSS::VA526ezSubmitTransaction] the user's transactions
      #
      def self.find_transactions(user)
        VA526ezSubmitTransaction.for_user(user)
      end

      # Updates a transaction
      #
      # @param user [User] The user associated with the transaction
      # @param status [Symbol] a valid VA526ezSubmitTransaction::JOB_STATUS key
      # @param response_body [Hash|String] the response body of the last request
      # @return [Boolean] did the update succeed
      #
      def self.update_transaction(job_id, status, response_body)
        raise ArgumentError, "#{status} is not a valid status" unless JOB_STATUS.keys.include?(status)
        transaction = VA526ezSubmitTransaction.find_transaction(job_id)
        transaction.update(
          status: COMPLETED,
          transaction_status: JOB_STATUS[status],
          metadata: response_body
        )
      end
    end
  end
end
