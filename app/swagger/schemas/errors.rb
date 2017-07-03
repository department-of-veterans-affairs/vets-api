# frozen_string_literal: true

module Swagger
  module Schemas
    class Errors
      include Swagger::Blocks

      swagger_schema :Errors do
        key :required, [:errors]

        property :errors do
          key :type, :array
          items do
            key :'$ref', :Error
          end
        end
      end

      swagger_schema :Error do
        key :required, [:title, :detail, :code, :status]
        property :title, type: :string
        property :detail, type: :string
        property :code, type: :string
        property :status, type: :string
      end

      swagger_schema :Meta do
        key :description, 'The response from the EVSS service to vets-api'
        key :required, [:status]
        property :status, type: :string, enum: ['OK', 'NOT_FOUND', 'SERVER_ERROR', 'NOT_AUTHORIZED']
      end
    end
  end
end
