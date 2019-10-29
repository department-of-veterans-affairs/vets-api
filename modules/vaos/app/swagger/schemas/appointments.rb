# frozen_string_literal: true

module Swagger
  module Schemas
    module VAOS
      class Appointments
        include Swagger::Blocks

        swagger_schema :Appointments do
          key :required, [:data, :meta]
          property :data do
            items do
            key :type, :array
              key :'$ref', 'appointments'
            end
          end
          property :meta, type: :object do
            key :required, [:pagination]
            property :pagination, type: :object do
              key :required, [:current_page, :per_page, :total_pages, :total_entries]
              property :current_page, type: :integer, example: 'TODO'
              property :per_page, type: :integer, example: 'TODO'
              property :total_pages, type: :integer, example: 'TODO'
              property :total_entries, type: :integer, example: 'TODO'
            end
          end
        end
      end
    end
  end
end
