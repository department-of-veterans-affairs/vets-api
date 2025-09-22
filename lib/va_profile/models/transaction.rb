# frozen_string_literal: true

require_relative 'base'
require_relative 'message'

module VAProfile
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

      attribute :messages, VAProfile::Models::Message, array: true
      attribute :id, String
      attribute :status, String

      def received?
        status == 'RECEIVED'
      end

      def completed_success?
        status == 'COMPLETED_SUCCESS'
      end

      # Converts a decoded JSON response from VAProfile to an instance of the Transaction model
      # @param body [Hash] the decoded response body from VAProfile
      # @return [VAProfile::Models::Transaction] the model built from the response body
      def self.build_from(body)
        messages = body['tx_messages']&.map { |m| VAProfile::Models::Message.build_from(m) }
        VAProfile::Models::Transaction.new(
          messages: messages || [],
          id: body['tx_audit_id'],
          status: body['tx_status'] || body['status']
        )
      end
    end
  end
end
