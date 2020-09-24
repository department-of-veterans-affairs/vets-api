# frozen_string_literal: true

module Swagger
  module Schemas
    class ValidVaFileNumber
      include Swagger::Blocks

      swagger_schema :ValidVaFileNumber do
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
