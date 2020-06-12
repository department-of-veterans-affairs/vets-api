# frozen_string_literal: true

module Swagger
  module Schemas
    class MaintenanceWindows
      include Swagger::Blocks

      swagger_schema :MaintenanceWindows do
        key :required, [:data]

        property :data, type: :array do
          items do
            property :id, type: :string
            property :type, type: :string

            property :attributes, type: :object do
              property :external_service, type: :string
              property :start_time, type: :string, format: :date
              property :end_time, type: :string, format: :date
              property :description, type: :string
            end
          end
        end
      end
    end
  end
end
