# frozen_string_literal: true

module ClaimsApi
  class ClaimsV0ControllerSwagger
    include Swagger::Blocks

    swagger_path '/services/claims/v0/claims/{id}' do
      operation :get do
        key :summary, 'Find Claim by ID'
        key :description, 'Returns a single claim if the user has access'
        key :operationId, 'findClaimById'
        key :tags, [
          'claim'
        ]
        parameter do
          key :name, :id
          key :in, :path
          key :description, 'ID of claims to fetch'
          key :required, true
          key :type, :integer
          key :format, :int64
        end
        response 200 do
          key :description, 'claims response'
          schema do
            key :'$ref', :Claims
          end
        end
        response :default do
          key :description, 'unexpected error'
          schema do
            key :'$ref', :ErrorModel
          end
        end
      end
    end
    swagger_path '/services/claims/v0/claims' do
      operation :get do
        key :summary, 'All Claims'
        key :description, 'Returns all claims from the system that the user has access to'
        key :operationId, 'findClaims'
        key :produces, [
          'application/json'
        ]
        key :tags, [
          'claims'
        ]
        parameter do
          key :name, :tags
          key :in, :query
          key :description, 'tags to filter by'
          key :required, false
          key :type, :array
          items do
            key :type, :string
          end
          key :collectionFormat, :csv
        end

        response 200 do
          key :description, 'claim response'
          schema do
            key :type, :array
            items do
              key :'$ref', :Claims
            end
          end
        end
        response :default do
          key :description, 'unexpected error'
          schema do
            key :'$ref', :ErrorModel
          end
        end
      end
    end
  end
end
