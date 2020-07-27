# frozen_string_literal: true

module Swagger
  module Schemas
    module Vet360
      class States
        include Swagger::Blocks

        swagger_schema :Vet360States do
          key :required, [:data]

          property :data, type: :object do
            key :required, [:attributes]
            property :attributes, type: :object do
              key :required, [:states]
              property :states do
                key :type, :array
                items do
                  property :state_name, type: :string, example: 'Oregon'
                  property :state_code, type: :string, example: 'OR'
                end
              end
            end
          end
        end
      end
    end
  end
end
