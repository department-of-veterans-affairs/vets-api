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
                  AsyncTransaction::Vet360::AddressTransaction
                  AsyncTransaction::Vet360::EmailTransaction
                  AsyncTransaction::Vet360::TelephoneTransaction
                ], example: 'AsyncTransaction::Vet360::EmailTransaction'
            end
          end
        end

        swagger_schema :AsyncTransactionsVet360 do
          key :required, [:data]
          property :data, type: :array
        end

      end
    end
  end
end
