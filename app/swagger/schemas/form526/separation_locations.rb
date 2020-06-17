# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class SeparationLocations
        include Swagger::Blocks
        swagger_schema :SeparationLocations do
          key :required, [:separation_locations]

          property :separation_locations, type: :array do
            items do
              key :required, %i[code description]
              property :code, type: :string, example: '98283'
              property :description, type: :string, example: 'AF Academy'
            end
          end
        end
      end
    end
  end
end
