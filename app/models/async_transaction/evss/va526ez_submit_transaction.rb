# frozen_string_literal: true

module AsyncTransaction
  module EVSS
    class VA526ezSubmitTransaction < AsyncTransaction::Base
      has_one :disability_compensation_submission,
              class_name: 'DisabilityCompensationSubmission',
              inverse_of: :disability_compensation_job,
              dependent: :destroy

      has_one :saved_claim,
              through: :disability_compensation_submission,
              source: :disability_compensation_claim

      alias_attribute :submission, :disability_compensation_submission

      JOB_STATUS = {
        submitted: 'submitted',
        received: 'received',
        retrying: 'retrying',
        non_retryable_error: 'non_retryable_error',
        exhausted: 'exhausted'
      }.freeze
      SOURCE = 'EVSS'

      # Creates an initial AsyncTransaction record for ongoing tracking and
      # set its transaction_status to submitted
      #
      # @param user [User] The user associated with the transaction
      # @param job_id [String] A sidekiq job id (uuid)
      # @return [AsyncTransaction::EVSS::VA526ezSubmitTransaction] the transaction
      #
      def self.start(user_uuid, edipi, job_id)
        create!(
          user_uuid: user_uuid,
          source_id: edipi,
          source: SOURCE,
          status: REQUESTED,
          transaction_status: JOB_STATUS[:submitted],
          transaction_id: job_id,
          metadata: {}
        )
      end

      # Finds a single transaction by job_id
      #
      # @param job_id [String] A sidekiq job id (uuid)
      # @return [AsyncTransaction::EVSS::VA526ezSubmitTransaction] the transaction
      #
      def self.find_transaction(job_id)
        result = VA526ezSubmitTransaction.find_by(transaction_id: job_id)
        return nil if result == []

        result
      end

      # Finds all of a users submit transactions
      #
      # @param user [User] The user associated with the transaction
      # @return [Array AsyncTransaction::EVSS::VA526ezSubmitTransaction] the user's transactions
      #
      def self.find_transactions(user_uuid)
        VA526ezSubmitTransaction.where(user_uuid: user_uuid)
      end

      # Updates a transaction
      #
      # @param user [User] The user associated with the transaction
      # @param status [Symbol] a valid VA526ezSubmitTransaction::JOB_STATUS key
      # @param response_body [Hash|String] the response body of the last request
      # @return [Boolean] did the update succeed
      #
      def self.update_transaction(job_id, status, response_body = nil)
        raise ArgumentError, "#{status} is not a valid status" unless JOB_STATUS.keys.include?(status)

        transaction = VA526ezSubmitTransaction.find_transaction(job_id)
        transaction.update_attributes(
          status: (status == :retrying ? REQUESTED : COMPLETED),
          transaction_status: JOB_STATUS[status],
          metadata: response_body || transaction.metadata
        )
      end
    end
  end
end
