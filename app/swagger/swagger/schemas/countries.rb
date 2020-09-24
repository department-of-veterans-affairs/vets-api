# frozen_string_literal: true

module Swagger
  module Schemas
    class Countries
      include Swagger::Blocks

      swagger_schema :Countries do
        key :required, [:data]

        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            key :required, [:countries]
            property :countries do
              key :type, :array
              items do
                key :required, [:name]
                property :name, type: :string, example: 'USA'
              end
            end
          end
        end
      end
    end
  end
end
