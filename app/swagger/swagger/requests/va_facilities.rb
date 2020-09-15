# frozen_string_literal: true

module Swagger
  module Requests
    class VAFacilities
      include Swagger::Blocks
      # rubocop:disable Layout/LineLength
      swagger_path '/v0/facilities/va' do
        operation :get do
          key :description, 'Get facilities within a geographic bounding box'
          key :operationId, 'indexFacilities'
          key :tags, %w[facilities]

          parameter do
            key :name, 'bbox[]'
            key :description, 'Bounding box Lat/Long coordinates in the form minLong, minLat, maxLong, maxLat'
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
            key :description, 'Optional facility type'
            key :in, :query
            key :type, :string
            key :enum, %w[health cemetery benefits vet_center]
          end
          parameter do
            key :name, 'services[]'
            key :description, 'Optional specialty services filter that works along with `type` param. Only available for types \'benefits\' and \'vet_center\'.'
            key :in, :query
            key :type, :array
            key :collectionFormat, :multi
            items do
              key :type, :string
            end
          end
          parameter do
            key :name, 'address'
            key :description, 'Address of search center, needed for searches involving community care providers'
            key :in, :query
            key :type, :string
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
      # rubocop:enable Layout/LineLength

      swagger_path '/v0/facilities/va/{id}' do
        operation :get do
          key :description, 'Get an individual facility detail object'
          key :operationId, 'showFacility'
          key :tags, %w[facilities]

          parameter do
            key :name, :id
            key :description, 'ID of facility such as vha_648A4'
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

      swagger_path '/v0/facilities/suggested' do
        operation :get do
          key :description, 'Given one or more facility types and a name part returns a list of suggested facilites'
          key :operationId, 'suggestedFacilities'
          key :tags, %w[facilities]

          parameter do
            key :name, 'type[]'
            key :description, 'facility type'
            key :in, :query
            key :type, :array
            key :collectionFormat, :multi
            items do
              key :type, :string
              key :enum, %w[health cemetery benefits vet_center dod_health]
            end
          end

          parameter do
            key :name, :name_part
            key :description, 'inputed partial facility name'
            key :in, :query
            key :type, :string
          end

          response 200 do
            key :description, 'Returns a list of facilities'
            schema do
              key :'$ref', :VAFacilities
            end
          end

          response 400 do
            key :description, 'Bad request: invalid type or missing name_part parameter'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end
    end
  end
end
