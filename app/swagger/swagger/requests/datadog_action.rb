# frozen_string_literal: true

module Swagger
  module Requests
    class DatadogAction
      include Swagger::Blocks

      swagger_path '/v0/datadog_action' do
        operation :post do
          key :summary, 'Record a front-end action in Datadog'
          key :operationId, 'recordDatadogAction'
          key :tags, ['Telemetry']

          parameter do
            key :name,        :metric
            key :in,          :body
            key :required,    true
            schema do
              key :$ref, :DatadogActionRequest
            end
          end

          response 204 do
            key :description, 'No Content'
          end
        end
      end

      swagger_component do
        schema :DatadogActionRequest do
          property :metric do
            key :type, :string
          end
          property :tags do
            key :type, :array
            items do
              key :type, :string
            end
          end
        end
      end
    end
  end
end
