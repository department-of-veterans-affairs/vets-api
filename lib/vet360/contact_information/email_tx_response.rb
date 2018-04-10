# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ContactInformation
    class EmailTxResponse < Vet360::TxResponse
      attribute :email, Hash

      def initialize(status, response = nil)
        @tx_audit_id = response&.body&.dig('txAuditId')
        super(status, response)
      end

    end
  end
end
