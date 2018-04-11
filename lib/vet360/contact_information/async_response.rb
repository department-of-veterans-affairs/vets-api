# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ContactInformation
    class AsyncResponse < Vet360::Response

      attr_reader :tx_audit_id

      def initialize(status, response = nil)
        @tx_audit_id = JSON.parse(response&.body)&.dig('txAuditId')
        super(status, tx_audit_id: @tx_audit_id)
      end

    end
  end
end
