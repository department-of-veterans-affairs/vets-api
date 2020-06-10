# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class IntakeSites
        include Swagger::Blocks
        swagger_schema :IntakeSites do
          key :required, [:intake_sites]

          property :intake_sites, type: :array do
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
