# frozen_string_literal: true

module Swagger
  module Schemas
    class States
      include Swagger::Blocks

      swagger_schema :States do
        key :required, [:data]

        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            key :required, [:states]
            property :states do
              key :type, :array
              items do
                key :required, [:name]
                property :name, type: :string, example: 'CA'
              end
            end
          end
        end
      end
    end
  end
end
