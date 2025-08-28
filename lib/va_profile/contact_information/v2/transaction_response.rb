# frozen_string_literal: true

require 'va_profile/models/transaction'
require 'va_profile/response'
require 'vets/shared_logging'

# rubocop:disable ThreadSafety/ClassInstanceVariable
module VAProfile
  module ContactInformation
    module V2
      class TransactionResponse < VAProfile::Response
        extend Vets::SharedLogging

        REDACTED_KEYS = %w[
          source_system_user
          address_line1
          address_line2
          address_line3
          city_name
          vet360_id
          county
          state_code
          zip_code5
          zip_code4
          phone_number
          email_address_text
          county_name
        ].freeze

        attribute :transaction, VAProfile::Models::Transaction
        ERROR_STATUS = 'COMPLETED_FAILURE'

        attr_reader :response_body

        def self.from(raw_response = nil)
          @response_body = raw_response&.body

          log_transaction_error if error?

          new(
            raw_response&.status,
            transaction: VAProfile::Models::Transaction.build_from(@response_body)
          )
        end

        def self.log_transaction_error
          redacted_response_body = redact_response_body(@response_body)

          log_message_to_sentry(
            'VAProfile contact info transaction error',
            :error,
            { response_body: redacted_response_body },
            error: :va_profile
          )
        end

        def self.redact_response_body(response_body)
          return unless response_body

          redacted_response_body = response_body.deep_dup
          redacted_response_body['tx_push_input']&.except!(*REDACTED_KEYS)
          redacted_response_body
        end

        def self.error?
          @response_body.try(:[], 'tx_status') == ERROR_STATUS
        end
      end

      class AddressTransactionResponse < TransactionResponse
        attribute :response_body, String

        def self.from(*args)
          return_val = super

          log_error

          return_val.response_body = @response_body
          return_val
        end

        def changed_field
          return :address unless response_body['tx_output']

          address_pou = response_body['tx_output'][0]['address_pou']
          if Settings.vsp_environment == 'staging'
            Rails.logger.info("AddressTransactionResponse CHANGED FIELD ADDRESS POU: #{address_pou}")
          end
          case address_pou
          when VAProfile::Models::V3::BaseAddress::RESIDENCE
            :residence_address
          when VAProfile::Models::V3::BaseAddress::CORRESPONDENCE
            :correspondence_address
          else
            :address
          end
        end

        def self.log_error
          if error?
            PersonalInformationLog.create(
              error_class: 'VAProfile::ContactInformation::V2::AddressTransactionResponseError',
              data:
                {
                  address: @response_body['tx_push_input'].except(
                    'address_id',
                    'originating_source_system',
                    'source_system_user',
                    'effective_start_date',
                    'va_profile_id'
                  ),
                  errors: @response_body['tx_messages']
                }
            )
          end
        rescue => e
          log_exception_to_sentry(e)
          log_exception_to_rails(e)
        end
      end

      class PersonTransactionResponse < TransactionResponse
        NOT_FOUND_IN_MPI_CODE = 'MVI201'

        def self.from(raw_response, user)
          return_val = super(raw_response)
          @user = user

          log_mpi_error if @user.mpi_status == :ok

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
          log_exception_to_rails(e)
        end
      end

      class EmailTransactionResponse < TransactionResponse
        attribute :response_body, String

        def self.from(*args)
          return_val = super

          return_val.response_body = @response_body

          return_val
        end

        def new_email
          tx_output = response_body['tx_output'][0]
          return if tx_output['effective_end_date'].present?

          tx_output['email_address_text']
        end
      end

      class TelephoneTransactionResponse < TransactionResponse
        attribute :response_body, String

        def self.from(*args)
          return_val = super

          return_val.response_body = @response_body
          return_val
        end

        def changed_field
          return :phone unless response_body['tx_output']

          phone_type = response_body['tx_output'][0]['phone_type']

          case phone_type
          when 'MOBILE'
            :mobile_phone
          when 'HOME'
            :home_phone
          when 'WORK'
            :work_phone
          else
            :phone
          end
        end
      end

      class PermissionTransactionResponse < TransactionResponse; end
    end
  end
end
# rubocop:enable ThreadSafety/ClassInstanceVariable
