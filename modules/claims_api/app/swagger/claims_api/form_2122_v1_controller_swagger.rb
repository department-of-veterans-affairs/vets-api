# frozen_string_literal: true

require_dependency 'claims_api/form_schemas'

module ClaimsApi
  class Form2122V1ControllerSwagger
    include Swagger::Blocks

    swagger_path '/forms/2122' do
      operation :get do
        key :summary, 'Get 2122 JSON Schema for form'
        key :description, 'Returns a single JSON schema to auto generate a form'
        key :operationId, 'get2122JsonSchema'
        key :produces, [
          'application/json'
        ]
        key :tags, [
          'Power of Attorney'
        ]

        response 200 do
          key :description, 'schema response'
          schema do
            key :type, :object
            key :required, [:data]
            property :data do
              key :type, :array
              items do
                key :type, :object
                key :description, 'Returning Variety of JSON and UI Schema Objects'
                key :example, ClaimsApi::FormSchemas::SCHEMAS['2122']
              end
            end
          end
        end

        response :default do
          key :description, 'unexpected error'
          schema do
            key :type, :object
            key :required, [:errors]
            property :errors do
              key :type, :array
              items do
                key :'$ref', :ErrorModel
              end
            end
          end
        end
      end

      operation :post do
        key :summary, 'Accepts 0966 Intent to File form submission'
        key :description, 'Accepts JSON payload. Full URL, including\nquery parameters.'
        key :operationId, 'post0966itf'
        key :tags, [
          'Power of Attorney'
        ]

        parameter do
          key :name, 'bearer_token'
          key :in, :header
          key :description, 'Oauth Token of Veteran requesting to access data'
          key :required, true
          key :type, :string
        end

        parameter do
          key :name, 'X-VA-SSN'
          key :in, :header
          key :description, 'SSN of Veteran to fetch'
          key :required, false
          key :type, :string
        end

        parameter do
          key :name, 'X-VA-First-Name'
          key :in, :header
          key :description, 'First Name of Veteran to fetch'
          key :required, false
          key :type, :string
        end

        parameter do
          key :name, 'X-VA-Last-Name'
          key :in, :header
          key :description, 'Last Name of Veteran to fetch'
          key :required, false
          key :type, :string
        end

        parameter do
          key :name, 'X-VA-Birth-Date'
          key :in, :header
          key :description, 'Date of Birth of Veteran to fetch in iso8601 format'
          key :required, false
          key :type, :string
        end

        parameter do
          key :name, 'X-VA-EDIPI'
          key :in, :header
          key :description, 'EDIPI Number of Veteran to fetch'
          key :required, false
          key :type, :string
        end

        parameter do
          key :name, 'X-VA-User'
          key :in, :header
          key :description, 'VA username of the person making the request'
          key :required, false
          key :type, :string
        end

        parameter do
          key :name, 'payload'
          key :in, :body
          key :description, 'JSON API Payload of Veteran being submitted'
          key :required, true
          schema do
            key :'$ref', :Form2122Input
          end
        end

        response 200 do
          key :description, '2122 response'
          schema do
            key :'$ref', :Form2122Output
          end
        end

        response :default do
          key :description, 'unexpected error'
          schema do
            key :type, :object
            key :required, [:errors]
            property :errors do
              key :type, :array
              items do
                key :'$ref', :ErrorModel
              end
            end
          end
        end
      end
    end

    swagger_path '/forms/2122/status' do
      operation :get do
        key :summary, 'Returns status of Power of Attorney form submission'
        key :description, 'Returns last active JSON payload. Full URL, including\nquery parameters.'
        key :operationId, 'get2122poa'
        key :tags, [
          'Power of Attorney'
        ]

        parameter do
          key :name, 'bearer_token'
          key :in, :header
          key :description, 'Oauth Token of Veteran requesting to access data'
          key :required, true
          key :type, :string
        end

        parameter do
          key :name, 'X-VA-SSN'
          key :in, :header
          key :description, 'SSN of Veteran to fetch'
          key :required, false
          key :type, :string
        end

        parameter do
          key :name, 'X-VA-First-Name'
          key :in, :header
          key :description, 'First Name of Veteran to fetch'
          key :required, false
          key :type, :string
        end

        parameter do
          key :name, 'X-VA-Last-Name'
          key :in, :header
          key :description, 'Last Name of Veteran to fetch'
          key :required, false
          key :type, :string
        end

        parameter do
          key :name, 'X-VA-Birth-Date'
          key :in, :header
          key :description, 'Date of Birth of Veteran to fetch in iso8601 format'
          key :required, false
          key :type, :string
        end

        parameter do
          key :name, 'X-VA-EDIPI'
          key :in, :header
          key :description, 'EDIPI Number of Veteran to fetch'
          key :required, false
          key :type, :string
        end

        parameter do
          key :name, 'X-VA-User'
          key :in, :header
          key :description, 'VA username of the person making the request'
          key :required, false
          key :type, :string
        end

        response 200 do
          key :description, '2122 response'
          schema do
            key :'$ref', :Form2122Output
          end
        end

        response :default do
          key :description, 'unexpected error'
          schema do
            key :type, :object
            key :required, [:errors]
            property :errors do
              key :type, :array
              items do
                key :'$ref', :ErrorModel
              end
            end
          end
        end
      end
    end
  end
end
