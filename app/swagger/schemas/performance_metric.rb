# frozen_string_literal: true

module Swagger
  module Schemas
    class PerformanceMetric
      include Swagger::Blocks

      swagger_schema :PerformanceMetric do
        key :required, %i[page_id metrics]
        property :page_id,
                 type: :string,
                 example: 'some_unique_page_indentifier',
                 description: 'A unique identifier for the frontend page being benchmarked'
        property :metrics do
          key :type, :array
          key :description, 'A collection of benchmark metrics and durations for a given page'
          items do
            key :required, %i[metric duration]
            property :metric,
                     type: :string,
                     example: 'initial_page_load',
                     description: 'Creates a namespace/bucket for what is being measured.'
            property :duration,
                     type: :float,
                     example: 100.1,
                     description: 'Duration of benchmark measurement in milliseconds'
          end
        end
      end
    end
  end
end
