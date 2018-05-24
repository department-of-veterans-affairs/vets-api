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

      attribute :messages, Array[Vet360::Models::Message]
      attribute :id, String
      attribute :status, String

      # Converts a decoded JSON response from Vet360 to an instance of the Transaction model
      # @param body [Hash] the decoded response body from Vet360
      # @return [Vet360::Models::Transaction] the model built from the response body
      def self.build_from(body)
        messages = body['tx_messages']&.map { |m| Vet360::Models::Message.build_from(m) }
        Vet360::Models::Transaction.new(
          messages: messages || [],
          id: body['tx_audit_id'],
          status: body['status']
        )
      end
    end
  end
end
