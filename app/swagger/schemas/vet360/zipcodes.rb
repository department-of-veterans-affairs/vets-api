# frozen_string_literal: true

module Swagger
  module Schemas
    module Vet360
      class Zipcodes
        include Swagger::Blocks

        swagger_schema :Vet360Zipcodes do
          key :required, [:data]

          property :data, type: :object do
            key :required, [:attributes]
            property :attributes, type: :object do
              key :required, [:zipcodes]
              property :zipcodes do
                key :type, :array
                items do
                  property :zip_code, type: :string, example: '97062'
                end
              end
            end
          end
        end
      end
    end
  end
end
