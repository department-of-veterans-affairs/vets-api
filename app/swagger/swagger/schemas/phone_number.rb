# frozen_string_literal: true

module Swagger
  module Schemas
    class PhoneNumber
      include Swagger::Blocks

      swagger_schema :PhoneNumber do
        key :required, [:data]

        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            property :number, type: :string, example: '4445551212'
            property :extension, type: :string, example: '101'
            property :country_code, type: :string, example: '1'
            property :effective_date, type: :string, example: '2018-03-26T15:41:37.487Z'
          end
        end
      end
    end
  end
end
