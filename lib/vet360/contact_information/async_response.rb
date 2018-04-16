# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ContactInformation
    class AsyncResponse < Vet360::Response

      attr_reader :tx_audit_id

      def initialize(status, transactionModel = nil)
        # @tx_audit_id = transactionModel.transaction_id
        @tx_audit_id = 1 # @TODO ^ This is what it should be when Harry's branch gets merged
        super(status, tx_audit_id: @tx_audit_id)
      end

    end
  end
end
