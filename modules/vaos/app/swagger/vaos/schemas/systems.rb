# frozen_string_literal: true

module VAOS
  module Schemas
    class Systems
      include Swagger::Blocks

      swagger_schema :Systems do
        key :required, [:data]

        property :data, type: :array do
          items do
            key :'$ref', :System
          end
        end
      end

      swagger_schema :System do
        key :required, %i[unique_id assigning_authority assigning_code id_status]
        property :unique_id, type: :string, example: '552151510'
        property :assigning_authority, type: :string, enum: %w[ICN EDIPI UNKNOWN], example: 'ICN'
        property :assigning_code, type: :string, example: '989'
        property :id_status, type: :string, enum: %w[ACTIVE PERMANENT], example: 'ACTIVE'
      end
    end
  end
end
