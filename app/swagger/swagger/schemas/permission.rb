# frozen_string_literal: true

module Swagger
  module Schemas
    class Permission
      include Swagger::Blocks

      swagger_schema :Permission do
        key :required, [:data]

        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            property :permission_type, type: :string, example: 'TextPermission'
            property :permission_value, type: :boolean, example: true
          end
        end
      end
    end
  end
end
