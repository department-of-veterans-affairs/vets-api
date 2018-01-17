# frozen_string_literal: true

module Swagger
  module Requests
    class VAFacilities
      include Swagger::Blocks

      swagger_path '/v0/facilities/va' do
        operation :get do
          key :description, 'Get facilities within a geographic bounding box'
          key :operationId, 'indexFacilities'
          key :tags, %w[facilities]

          parameter do
            key :name, 'bbox[]'
            key :in, :query
            key :type, :array
            key :required, true
            key :collectionFormat, :multi
            key :minItems, 4
            key :maxItems, 4
            items do
              key :type, :number
            end
          end
          parameter do
            key :name, :type
            key :in, :query
            key :type, :string
            key :enum, %w[health cemetery benefits vet_center]
          end
          parameter do
            key :name, 'services[]'
            key :in, :query
            key :type, :array
            key :collectionFormat, :multi
            items do
              key :type, :string
            end
          end
          response 200 do
            key :description, 'Successful bounding box query'
            schema do
              key :'$ref', :VAFacilities
            end
          end
          response 400 do
            key :description, 'Invalid bounding box query'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end

      swagger_path '/v0/facilities/va/{id}' do
        operation :get do
          key :description, 'Get an individual facility detail object'
          key :operationId, 'showFacility'
          key :tags, %w[facilities]

          parameter do
            key :name, :id
            key :in, :path
            key :type, :string
            key :required, true
          end
          response 200 do
            key :description, 'Successful facility detail lookup'
            schema do
              key :'$ref', :VAFacility
            end
          end
          response 404 do
            key :description, 'Non-existent facility lookup'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end
    end
  end
end
