# frozen_string_literal: true

module Swagger
  module Schemas
    class Appeals
      include Swagger::Blocks

      swagger_schema :Appeals do
        key :required, [:data]
        property :data, type: :array
      end

      swagger_schema :AppealsErrors do
        key :type, :object
        items do
          key :type, :object
          property :title, type: :string
          property :detail, type: :string
        end
      end
    end
  end
end
