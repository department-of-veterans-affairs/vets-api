# frozen_string_literal: true

require 'va_profile/models/transaction'
require 'va_profile/response'

module VAProfile
  module ContactInformation
    class TransactionResponse < VAProfile::Response
      extend SentryLogging

      attribute :transaction, VAProfile::Models::Transaction
      ERROR_STATUS = 'COMPLETED_FAILURE'

      attr_reader :response_body

      def self.from(raw_response = nil)
        @response_body = raw_response&.body

        if error?
          log_message_to_sentry(
            'VAProfile transaction error',
            :error,
            { response_body: @response_body },
            error: :va_profile
          )
        end

        new(
          raw_response&.status,
          transaction: VAProfile::Models::Transaction.build_from(@response_body)
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
            error_class: 'VAProfile::ContactInformation::AddressTransactionResponseError',
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

    class PersonTransactionResponse < TransactionResponse
      NOT_FOUND_IN_MPI_CODE = 'MVI201'

      def self.from(raw_response, user)
        return_val = super(raw_response)
        @user = user

        log_mpi_error if @user.mpi_status == Common::Client::Concerns::ServiceStatus::RESPONSE_STATUS[:ok]

        return_val
      end

      def self.log_mpi_error
        if error?
          @response_body['tx_messages'].each do |tx_message|
            if tx_message['code'] == NOT_FOUND_IN_MPI_CODE
              return log_message_to_sentry(
                'va profile mpi not found',
                :error,
                {
                  icn: @user.icn,
                  edipi: @user.edipi,
                  response_body: @response_body
                },
                error: :va_profile
              )
            end
          end
        end
      rescue => e
        log_exception_to_sentry(e)
      end
    end

    class EmailTransactionResponse < TransactionResponse; end
    class TelephoneTransactionResponse < TransactionResponse; end
    class PermissionTransactionResponse < TransactionResponse; end
  end
end
