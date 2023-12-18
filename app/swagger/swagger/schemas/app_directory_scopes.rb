# frozen_string_literal: true

module Swagger
  module Schemas
    class AppDirectoryScopes
      include Swagger::Blocks

      swagger_schema :AppDirectoryScopes do
        key :required, %i[name displayName description]
        property :type, type: :array
        items do
          property :name, type: :string
          property :displayName, type: :string
          property :description, type: :string
        end
      end
    end
  end
end
