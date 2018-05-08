# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class Base < AsyncTransaction::Base
      FINAL_STATUSES = %w[
        REJECTED
        COMPLETED_SUCCESS
        COMPLETED_NO_CHANGES_DETECTED
        COMPLETED_FAILURE
      ].freeze

      # Updates the status and transaction_status with fresh API data
      # @params user [User] the user whose tx data is being updated
      # @params service [Vet360::ContactInformation::Service] an initialized vet360 client
      # @params tx_id [int] the transaction_id
      # @returns [AsyncTransaction::Vet360::Base]
      def self.refresh_transaction_status(user, service, tx_id = nil)
        transaction_record = Base.find_by!(user_uuid: user.uuid, transaction_id: tx_id)
        # No need for a API request if this tx is already complete
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
          raise Common::Exceptions::InternalServerError, transaction_record
        end
      end

      # Returns true if a transaction is "over"
      # @return [Boolean]
      def finished?
        # These SHOULD go hand-in-hand...
        return true if FINAL_STATUSES.include? transaction_status
        return true if COMPLETED == status
        false
      end
    end
  end
end
