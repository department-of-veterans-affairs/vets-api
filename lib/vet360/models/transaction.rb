# frozen_string_literal: true

module Vet360
  module Models
    class Transaction < Base
      STATUSES = %w[
        REJECTED
        RECEIVED
        RECEIVED_ERROR_QUEUE
        RECEIVED_DEAD_LETTER_QUEUE
        COMPLETED_SUCCESS
        COMPLETED_NO_CHANGES_DETECTED
        COMPLETED_FAILURE
      ].freeze

      attribute :messages, Array[Message]
      attribute :id, String
      attribute :status, String

      def self.from_response(body)
        messages = body['messages']&.map { |m| Vet360::Models::Message.from_response(m) }

        Vet360::Models::TransactionStatus.new(
          messages: messages,
          id: body['tx_audit_id'],
          status: body['tx_status']
        )
      end
    end
  end
end
