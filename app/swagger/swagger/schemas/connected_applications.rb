# frozen_string_literal: true

module Swagger
  module Schemas
    class ConnectedApplications
      include Swagger::Blocks

      swagger_schema :ConnectedApplications do
        key :required, [:data]
        property :data, type: :array do
          items do
            property :id, type: :string
            property :type, type: :string
            property :attributes, type: :object do
              property :title, type: :string
              property :created, type: :string
              property :logo, type: :string
              property :grants, type: :array do
                items do
                  property :id, type: :string
                  property :title, type: :string
                end
              end
            end
          end
        end
      end
    end
  end
end
