# frozen_string_literal: true

module Swagger
  module Schemas
    module Appeals
      class Requests
        include Swagger::Blocks

        swagger_schema :Appeals do
          key :type, :object
          key :required, %i[data]
          property :data, type: :array do
            items type: :object do
            end
          end
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
end
