# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class Base < AsyncTransaction::Base;

      def self.refresh_transaction_status(user, tx_id = nil)

        transaction_record = Base.find_by(user_uuid: user.uuid, transaction_id: tx_id)

        return unless transaction_record

        vet360_service = ::Vet360::ContactInformation::Service.new(user) # @TODO this is stinky
        response = case transaction_record
        when AsyncTransaction::Vet360::AddressTransaction
          vet360_service.get_address_transaction_status(transaction_record.transaction_id)
        when AsyncTransaction::Vet360::EmailTransaction
          vet360_service.get_email_transaction_status(transaction_record.transaction_id)
        when AsyncTransaction::Vet360::TelephoneTransaction
          vet360_service.get_telephone_transaction_status(transaction_record.transaction_id)
        else
          # @TODO raise exception
        end

        #@TODO Do we need error handling here or let the client do it?

        transaction_record.update!(transaction_status: response.transaction.status)
        return transaction_record

      end
    end
  end
end
