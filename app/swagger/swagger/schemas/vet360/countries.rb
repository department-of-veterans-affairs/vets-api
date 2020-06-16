# frozen_string_literal: true

module Swagger
  module Schemas
    module Vet360
      class Countries
        include Swagger::Blocks

        swagger_schema :Vet360Countries do
          key :required, [:data]

          property :data, type: :object do
            key :required, [:attributes]
            property :attributes, type: :object do
              key :required, [:countries]
              property :countries do
                key :type, :array
                items do
                  property :country_name, type: :string, example: 'Italy'
                  property :country_code_iso3, type: :string, example: 'ITA'
                end
              end
            end
          end
        end
      end
    end
  end
end
