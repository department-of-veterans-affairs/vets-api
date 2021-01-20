# frozen_string_literal: true

module Swagger
  module Schemas
    class ValidVAFileNumber
      include Swagger::Blocks

      swagger_schema :ValidVAFileNumber do
        key :required, [:data]

        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            property :valid_va_file_number, type: :boolean, example: true
          end
        end
      end
    end
  end
end
