# frozen_string_literal: true

module AsyncTransaction
  module CentralMail
    class VA4142SubmitTransaction < AsyncTransaction::Base
      JOB_STATUS = {
        submitted: 'submitted',
        received: 'received',
        retrying: 'retrying',
        non_retryable_error: 'non_retryable_error',
        exhausted: 'exhausted'
      }.freeze
      SOURCE = 'central_mail'

      scope :for_user, ->(user_uuid) { where(user_uuid: user_uuid) }
      scope :job_id, ->(job_id) { where(transaction_id: job_id) }

      # Creates an initial AsyncTransaction record for ongoing tracking and
      # set its transaction_status to submitted
      #
      # @param user_uuid [String] The user uuid associated with the transaction
      # @param user_edipi [String] The user edipi associated with the transaction
      # @param job_id [String] A sidekiq job id (uuid)
      # @return [AsyncTransaction::CentralMail::VA4142SubmitTransaction] the transaction
      #
      def self.start(user_uuid, user_edipi, job_id)
        create!(
          user_uuid: user_uuid,
          source_id: user_edipi,
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
      # @return [AsyncTransaction::CentralMail::VA4142SubmitTransaction] the transaction
      #
      def self.find_transaction(job_id)
        result = VA4142SubmitTransaction.job_id(job_id)
        return nil if result == []
        result
      end

      # Finds all of a users submit transactions
      #
      # @param user_uuid [String] The user uuid associated with the transaction
      # @return [Array AsyncTransaction::CentralMail::VA4142SubmitTransaction] the user's transactions
      #
      def self.find_transactions(user_uuid)
        VA4142SubmitTransaction.for_user(user_uuid)
      end

      # Updates a transaction
      #
      # @param job_id [String] ID associated with the transaction
      # @param status [Symbol] a valid VA4142SubmitTransaction::JOB_STATUS key
      # @param response_body [Hash|String] the response body of the last request
      # @return [Boolean] did the update succeed
      #
      def self.update_transaction(job_id, status, response_body = nil)
        raise ArgumentError, "#{status} is not a valid status" unless JOB_STATUS.keys.include?(status)
        transaction = VA4142SubmitTransaction.find_transaction(job_id)
        transaction.first.update(
          status: (status == :retrying ? REQUESTED : COMPLETED),
          transaction_status: JOB_STATUS[status],
          metadata: response_body || transaction.metadata
        )
      end
    end
  end
end
