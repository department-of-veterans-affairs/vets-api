# frozen_string_literal: true

module Vet360
  module Models
    class TransactionStatus < Base
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
      attribute :status, String
      attribute :transaction_id, String
      attribute :transaction_status, String

      validates(
        :status,
        presence: true,
        inclusion: { in: STATUSES }
      )

      validates(
        :transaction_status,
        presence: true,
        inclusion: { in: STATUSES }
      )
    end
  end
end
