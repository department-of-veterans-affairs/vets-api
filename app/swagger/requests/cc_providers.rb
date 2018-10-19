
# frozen_string_literal: true

module Swagger
  module Requests
    class CCProviders
      include Swagger::Blocks
      swagger_path '/v0/facilities/ccp/{id}' do
        operation :get do
          key :description, 'Get an individual community care provider'
          key :operationId, 'showProvider'
          key :tags, %w[facilities]

          parameter do
            key :name, :id
            key :description, 'ID of facility such as ccp_1780780627'
            key :in, :path
            key :type, :string
            key :required, true
          end
          response 200 do
            key :description, 'Successful provider detail lookup'
            schema do
              key :'$ref', :CCProvider
            end
          end
          response 400 do
            key :description, 'Invalid id provider lookup'
            schema do
              key :'$ref', :Errors
            end
          end
          response 404 do
            key :description, 'Non-existent provider lookup'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end

      swagger_path '/v0/facilities/services' do
        operation :get do
          key :description, 'Get complete list of specialties/services from ppms'
          key :operationId, 'specialties'
          key :tags, %w[facilities]

          response 200 do
            key :description, 'Successful specialties lookup'
            schema do
              key :'$ref', :CCSpecialties
            end
          end
        end
      end
    end
  end
end
