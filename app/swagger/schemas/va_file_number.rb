# frozen_string_literal: true

module Swagger
  module Schemas
    class VaFileNumber
      include Swagger::Blocks

      swagger_schema :VaFileNumber do
        key :required, [:data]

        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            property :va_file_number, type: :string, example: '796148937'
          end
        end
      end
    end
  end
end
