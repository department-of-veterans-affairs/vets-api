# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class Base < AsyncTransaction::Base
      # :nocov:
      FINAL_STATUSES = %w[
        REJECTED
        COMPLETED_SUCCESS
        COMPLETED_NO_CHANGES_DETECTED
        COMPLETED_FAILURE
      ].freeze
      REQUESTED = 'requested'
      COMPLETED = 'completed'
      # :nocov:

      # Creates an initial AsyncTransaction record for ongoing tracking
      #
      # @param user [User] The user associated with the transaction
      # @param response [Vet360::ContactInformation::TransactionResponse] An instance of
      #   a Vet360::ContactInformation::TransactionResponse class, be it Email, Address, etc.
      # @return [AsyncTransaction::Vet360::Base] A AsyncTransaction::Vet360::Base record, be it Email, Address, etc.
      #
      def self.start(user, response)
        create(
          user_uuid: user.uuid,
          source_id: user.vet360_id,
          source: 'vet360',
          status: REQUESTED,
          transaction_id: response.transaction.id,
          transaction_status: response.transaction.status
        )
      end

      # Updates the status and transaction_status with fresh API data
      # @params user [User] the user whose tx data is being updated
      # @params service [Vet360::ContactInformation::Service] an initialized vet360 client
      # @params tx_id [int] the transaction_id
      # @returns [AsyncTransaction::Vet360::Base]
      def self.refresh_transaction_status(user, service, tx_id = nil)
        transaction_record = Base.find_by!(user_uuid: user.uuid, transaction_id: tx_id)
        return transaction_record if transaction_record.finished?
        api_response = Base.fetch_transaction(transaction_record, service)
        transaction_record.status = COMPLETED if FINAL_STATUSES.include? api_response.transaction.status
        transaction_record.transaction_status = api_response.transaction.status
        transaction_record.save!
        transaction_record
      end

      # Requests a transaction from vet360 for an app transaction
      # @params user [User] the user whose tx data is being updated
      # @params transaction_record [AsyncTransaction::Vet360::Base] the tx record to be checked
      # @params service [Vet360::ContactInformation::Service] an initialized vet360 client
      # @returns [Vet360::Models::Transaction]
      def self.fetch_transaction(transaction_record, service)
        case transaction_record
        when AsyncTransaction::Vet360::AddressTransaction
          service.get_address_transaction_status(transaction_record.transaction_id)
        when AsyncTransaction::Vet360::EmailTransaction
          service.get_email_transaction_status(transaction_record.transaction_id)
        when AsyncTransaction::Vet360::TelephoneTransaction
          service.get_telephone_transaction_status(transaction_record.transaction_id)
        else
          # Unexpected transaction type means something went sideways
          raise
        end
      end

      # Returns true if a transaction is "over"
      # @return [Boolean]
      def finished?
        # These SHOULD go hand-in-hand...
        FINAL_STATUSES.include?(transaction_status) || status == COMPLETED
      end
    end
  end
end
