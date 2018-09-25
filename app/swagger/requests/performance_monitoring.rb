# frozen_string_literal: true

module Swagger
  module Requests
    class PerformanceMonitoring
      include Swagger::Blocks

      swagger_path '/v0/performance_monitorings' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Call StatsD.measure with the passed page performance benchmarking data.'
          key :operationId, 'postPerformanceMonitoring'
          key :tags, %w[
            performance_monitoring
          ]

          parameter :authorization

          parameter do
            key :name, :body
            key :in, :body
            key :description, "Attributes to benckmark a page's performance in StatsD"
            key :required, true

            schema do
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
                           type: :number,
                           example: 100.1,
                           description: 'Duration of benchmark measurement in milliseconds'
                end
              end
            end
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :required, [:data]

              property :data, type: :object do
                key :required, [:attributes]
                property :id, type: :string
                property :type, type: :string
                property :attributes, type: :object do
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
                               example: 'frontend.page_performance.initial_page_load',
                               description: 'Creates a namespace/bucket for what is being measured.'
                      property :duration,
                               type: :string,
                               example: '100.1',
                               description: 'Duration of benchmark measurement in milliseconds'
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
