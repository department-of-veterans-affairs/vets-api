# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ContactInformation
    class TransactionStatusResponse < Vet360::Response
      attribute :transaction, Vet360::Models::Transaction

      attr_reader :trx

      def initialize(status, response = nil)
        @trx = response&.body

        super(status, transaction: Vet360::Models::Transaction.from_response(@trx))
      end
    end

    class AddressTransactionStatusResponse < TransactionStatusResponse; end
    class EmailTransactionStatusResponse < TransactionStatusResponse; end
    class TelephoneTransactionStatusResponse < TransactionStatusResponse; end
  end
end
