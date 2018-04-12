# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ContactInformation
    class TransactionStatusResponse < Vet360::Response
      attribute :transaction_status

      attr_reader :trx

      def initialize(status, response = nil)
        @trx = response&.body
byebug
        super(
          status,
          transaction_status: Vet360::Models::TransactionStatus.from_response(@trx)
        )
      end
    end
  end
end
