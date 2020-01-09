# frozen_string_literal: true

require_dependency 'claims_api/form_schemas'

module ClaimsApi
  module V0
    class Form2122ControllerSwagger
      include Swagger::Blocks

      swagger_path '/forms/2122' do
        operation :get do
          key :description, 'Returns a single 2122 JSON schema to auto generate a form'
          key :summary, 'Get 2122 JSON Schema for form'
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
          key :summary, 'Accepts 2122 Power of Attorney form submission'
          key :description, 'Accepts JSON payload. Full URL, including query parameters.'
          key :operationId, 'post2122poa'
          key :tags, [
            'Power of Attorney'
          ]

          security do
            key :apikey, []
          end

          parameter do
            key :name, 'X-VA-SSN'
            key :in, :header
            key :description, 'SSN of Veteran to fetch'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran to fetch'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran to fetch'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran to fetch in iso8601 format'
            key :required, true
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
            key :name, 'X-VA-LOA'
            key :in, :header
            key :description, 'The level of assurance of the user making the request'
            key :example, '3'
            key :required, true
            key :type, :string
          end

          request_body do
            key :description, 'JSON API Payload of Veteran being submitted'
            key :required, true
            content 'application/json' do
              schema do
                key :'$ref', :Form2122Input
              end
            end
          end

          response 200 do
            key :description, '0966 response'
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

      swagger_path '/forms/2122/{id}' do
        operation :put do
          key :summary, 'Upload Power of attorney document'
          key :description, 'Accepts a document binary as part of a multipart payload.'
          key :operationId, 'upload2122Attachments'
          key :produces, [
            'application/json'
          ]
          key :tags, [
            'Power of Attorney'
          ]

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'UUID given when Power of Attorney was submitted'
            key :required, true
            key :type, :uuid
          end

          parameter do
            key :name, 'apikey'
            key :in, :header
            key :description, 'API Key given to access data'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-SSN'
            key :in, :header
            key :description, 'SSN of Veteran to fetch'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran to fetch'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran to fetch'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran to fetch in iso8601 format'
            key :required, true
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
            key :name, 'X-VA-LOA'
            key :in, :header
            key :description, 'The level of assurance of the user making the request'
            key :example, '3'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'attachment'
            key :in, :formData
            key :type, :file
            key :description, 'Attachment contents. Must be provided in PDF format and less than 11 in x 11 in'
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

        operation :get do
          key :summary, 'Check 2122 Status by ID'
          key :description, 'Returns last active JSON payload. Full URL, including\nquery parameters.'
          key :operationId, 'get2122poa'
          key :tags, [
            'Power of Attorney'
          ]

          security do
            key :apikey, []
          end

          parameter do
            key :name, 'X-VA-SSN'
            key :in, :header
            key :description, 'SSN of Veteran to fetch'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran to fetch'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran to fetch'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran to fetch in iso8601 format'
            key :required, true
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
            key :name, 'X-VA-LOA'
            key :in, :header
            key :description, 'The level of assurance of the user making the request'
            key :example, '3'
            key :required, true
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
end
