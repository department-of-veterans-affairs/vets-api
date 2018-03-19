# frozen_string_literal: true
require 'backend_services'

module Swagger
  module Requests
    class BackendStatuses
      include Swagger::Blocks

      swagger_path '/v0/backend_statuses/{service}' do
        operation :get do

          key :description, 'Gets the status of backend service'
          key :operationId, 'getBackendStatus'

          parameter do
            key :name, 'service'
            key :in, :path
            key :description, 'The name of the backend service'
            key :required, true
            key :type, :string
            key :enum, BackendServices.all
          end

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Availability
            end
          end
        end
      end

      swagger_schema :Availability do
        key :required, %i[data]
        property :data, type: :object do
          key :required, %i[attributes]
          property :id, type: :string
          property :type, type: :string
          property :attributes, type: :object do
            key :required, %i[name is_available]
            property :is_available, type: :boolean, example: true
            property :name, type: :string, example: 'gibs'
          end
        end
      end
    end
  end
end
