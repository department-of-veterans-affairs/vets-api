# frozen_string_literal: true

require 'vet360/models/transaction'
require 'vet360/response'

module Vet360
  module ContactInformation
    class TransactionResponse < Vet360::Response
      extend SentryLogging

      attribute :transaction, Vet360::Models::Transaction
      ERROR_STATUS = 'COMPLETED_FAILURE'

      attr_reader :response_body

      def self.from(raw_response = nil)
        @response_body = raw_response&.body

        if error?
          log_message_to_sentry(
            'Vet360 transaction error',
            :error,
            { response_body: @response_body },
            error: :vet360
          )
        end

        new(
          raw_response&.status,
          transaction: Vet360::Models::Transaction.build_from(@response_body)
        )
      end

      def self.error?
        @response_body.try(:[], 'tx_status') == ERROR_STATUS
      end
    end

    class AddressTransactionResponse < TransactionResponse
      def self.from(*args)
        return_val = super

        log_error

        return_val
      end

      def self.log_error
        if error?
          PersonalInformationLog.create(
            error_class: 'Vet360::ContactInformation::AddressTransactionResponseError',
            data:
              {
                address: @response_body['tx_push_input'].except(
                  'address_id',
                  'originating_source_system',
                  'source_system_user',
                  'effective_start_date',
                  'vet360_id'
                ),
                errors: @response_body['tx_messages']
              }
          )
        end
      rescue => e
        log_exception_to_sentry(e)
      end
    end
    class EmailTransactionResponse < TransactionResponse; end
    class PersonTransactionResponse < TransactionResponse; end
    class TelephoneTransactionResponse < TransactionResponse; end
    class PermissionTransactionResponse < TransactionResponse; end
  end
end
