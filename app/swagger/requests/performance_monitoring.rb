# frozen_string_literal: true

# rubocop:disable Layout/LineLength
module Swagger
  module Requests
    class PerformanceMonitoring
      include Swagger::Blocks

      swagger_path '/v0/performance_monitorings' do
        operation :post do
          key :description, 'Call StatsD.measure with the passed page performance benchmarking data.'
          key :operationId, 'postPerformanceMonitoring'
          key :tags, %w[
            performance_monitoring
          ]

          parameter do
            key :name, :body
            key :in, :body
            key :description, "Attributes to benckmark a page's performance in StatsD"
            key :required, true

            schema do
              property :data,
                       type: :string,
                       example: '{\"page_id\":\"/\",\"metrics\":[{\"metric\":\"totalPageLoad\",\"duration\":1234.56},{\"metric\":\"firstContentfulPaint\",\"duration\":123.45}]}',
                       description: '
 A JSON string of metrics data.  The required structure is an object with two properties: page_id (string) and metrics (array).

 page_id is a whitelisted path. See vets-api/lib/benchmark/whitelist.rb.

 The metrics property should contain an array of hashes, with each hash containing two properties: metric (string) and duration (float).

 For example
  {
    "page_id": "/disability/",
    "metrics": [
      {
        "metric": "totalPageLoad",
        "duration": 1234.56
      },
      {
        "metric": "firstContentfulPaint",
        "duration": 123.45
      }
    ]
  }
'
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
                           example: '/disability/',
                           description: 'A unique identifier for the frontend page being benchmarked'
                  property :metrics do
                    key :type, :array
                    key :description, 'A collection of benchmark metrics and durations for a given page'
                    items do
                      key :required, %i[metric duration]
                      property :metric,
                               type: :string,
                               example: 'frontend.page_performance.total_page_load',
                               description: 'Creates a namespace/bucket for what is being measured.'
                      property :duration,
                               example: 100.1,
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
# rubocop:enable Layout/LineLength
