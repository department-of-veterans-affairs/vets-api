# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class Base < AsyncTransaction::Base
      SENT = 'sent'

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
          status: SENT,
          transaction_id: response.transaction.id,
          transaction_status: response.transaction.status
        )
      end
    end
  end
end
