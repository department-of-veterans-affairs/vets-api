# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ContactInformation
    class TxResponse < Vet360::Response

      attr_reader :tx_audit_id

      def initialize(status, response = nil)
        @tx_audit_id = response&.body&.dig('txAuditId')
      end

    end
  end
end
