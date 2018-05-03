# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class Base < AsyncTransaction::Base

      FINAL_STATUSES = [
        'REJECTED',
        'COMPLETED_SUCCESS',
        'COMPLETED_NO_CHANGES_DETECTED',
        'COMPLETED_FAILURE',
        #'RECEIVED_DEAD_LETTER_QUEUE' #@TODO Do we know what this is?
      ]

      def self.refresh_transaction_status(user, service, tx_id = nil)

        transaction_record = Base.find_by(user_uuid: user.uuid, transaction_id: tx_id)

        raise Common::Exceptions::RecordNotFound, transaction_record unless transaction_record

        # No need for a API request if this tx is already complete
        return transaction_record if transaction_record.finished?

        api_response = Base.fetch_transaction(user, transaction_record, service)

        transaction_record.status = END_STATUS if FINAL_STATUSES.include? api_response.transaction.status
        transaction_record.transaction_status = api_response.transaction.status
        transaction_record.save!

        return transaction_record

      end

      def self.fetch_transaction(user, transaction_record, service)
        
        response = case transaction_record
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


      def finished?
        # These SHOULD go hand-in-hand
        return true if FINAL_STATUSES.include? self.transaction_status
        return true if END_STATUS == self.status
        
        return false
      end
    end
  end
end
