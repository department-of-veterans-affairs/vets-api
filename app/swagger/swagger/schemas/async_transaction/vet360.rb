# frozen_string_literal: true

module Swagger
  module Schemas
    module AsyncTransaction
      class Vet360
        include Swagger::Blocks

        swagger_schema :AsyncTransactionVet360 do
          key :required, [:data]

          property :data, type: :object do
            key :required, [:attributes]
            property :attributes, type: :object do
              property :transaction_status, type: :string, enum:
                %w[
                  REJECTED
                  RECEIVED
                  RECEIVED_ERROR_QUEUE
                  RECEIVED_DEAD_LETTER_QUEUE
                  COMPLETED_SUCCESS
                  COMPLETED_NO_CHANGES_DETECTED
                  COMPLETED_FAILURE
                ], example: 'RECEIVED'
              property :transaction_id, type: :string, example: '786efe0e-fd20-4da2-9019-0c00540dba4d'
              property :type, type: :string, enum:
                %w[
                  AsyncTransaction::VAProfile::AddressTransaction
                  AsyncTransaction::VAProfile::EmailTransaction
                  AsyncTransaction::VAProfile::InitializePersonTransaction
                  AsyncTransaction::VAProfile::PermissionTransaction
                  AsyncTransaction::VAProfile::TelephoneTransaction
                  AsyncTransaction::VAProfile::PersonOptionsTransaction
                ], example: 'AsyncTransaction::VAProfile::EmailTransaction'
              property :metadata, type: :array do
                items type: :object do
                  property :code, type: :string, example: 'CORE103'
                  property :key, type: :string, example: '_CUF_NOT_FOUND'
                  property :severity, type: :string, example: 'ERROR'
                  property :text, type: :string, example: 'The tx for id/criteria XZY could not be found.'
                end
              end
            end
          end
        end

        swagger_schema :AsyncTransactionsVet360 do
          key :required, [:data]
          property :data,
                   type: :array do
            items type: :object do
              key :required, [:attributes]
              property :attributes, type: :object do
                property :transaction_status, type: :string, enum:
                  %w[
                    REJECTED
                    RECEIVED
                    RECEIVED_ERROR_QUEUE
                    RECEIVED_DEAD_LETTER_QUEUE
                    COMPLETED_SUCCESS
                    COMPLETED_NO_CHANGES_DETECTED
                    COMPLETED_FAILURE
                  ], example: 'RECEIVED'
                property :transaction_id, type: :string, example: '786efe0e-fd20-4da2-9019-0c00540dba4d'
                property :type, type: :string, enum:
                  %w[
                    AsyncTransaction::VAProfile::AddressTransaction
                    AsyncTransaction::VAProfile::EmailTransaction
                    AsyncTransaction::VAProfile::InitializePersonTransaction
                    AsyncTransaction::VAProfile::PermissionTransaction
                    AsyncTransaction::VAProfile::TelephoneTransaction
                    AsyncTransaction::VAProfile::PersonOptionsTransaction
                  ], example: 'AsyncTransaction::VAProfile::AddressTransaction'
                property :metadata, type: :array do
                  items type: :object do
                    property :code, type: :string, example: 'CORE103'
                    property :key, type: :string, example: '_CUF_NOT_FOUND'
                    property :severity, type: :string, example: 'ERROR'
                    property :text, type: :string, example: 'The tx for id/criteria XZY could not be found.'
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
