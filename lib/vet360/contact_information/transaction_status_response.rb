# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ContactInformation
    class TransactionStatusResponse < Vet360::Response
      attr_reader :trx

      def initialize(status, response = nil)
        @trx = response&.body

        binding.pry

        super(status, transaction_status: bio)
      end

      def build_transaction_status
        Vet360::Models::TransactionStatus.new(
          messages: trx['messages'],
          status: trx['status'],
          transaction_id: trx['tx_audit_id'],
          transaction_status: trx['tx_status']
        )
      end
    end
  end
end
