# frozen_string_literal: true

require_dependency 'claims_api/form_schemas'

module ClaimsApi
  class Form526V1ControllerSwagger
    include Swagger::Blocks

    swagger_path '/forms/526' do
      operation :get do
        key :summary, 'Get 526 JSON Schema for form'
        key :description, 'Returns a single 526 JSON schema to auto generate a form'
        key :operationId, 'get526JsonSchema'
        key :produces, [
          'application/json'
        ]
        key :tags, [
          'Disability'
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
                key :example, ClaimsApi::FormSchemas::SCHEMAS['526']
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
        key :summary, 'Accepts 526 claim form submission'
        key :description, 'Accpets document binaries as part of a multipart payload. Accepts N number of attachments, via attachment1 .. attachmentN'
        key :operationId, 'post526Claim'
        key :tags, [
          'Disability'
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
            key :'$ref', :Form526Input
          end
        end

        response 200 do
          key :description, '526 response'
          schema do
            key :'$ref', :Claims
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

    swagger_path '/forms/526/validate' do
      operation :post do
        key :summary, 'Validates a 526 claim form submission'
        key :description, 'Accepts JSON payload. Full URL, including\nquery parameters.'
        key :operationId, 'post526ClaimValidate'
        key :tags, [
          'Disability'
        ]

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
          key :required, true
          key :type, :string
        end

        parameter do
          key :name, 'payload'
          key :in, :body
          key :description, 'JSON API Payload of Veteran being submitted'
          key :required, true
          schema do
            key :'$ref', :Form526Input
          end
        end

        response 200 do
          key :description, '526 response'
          schema do
            key :type, :object
            key :required, [:data]

            property :data do
              key :type, :object
              key :required, [:attributes]

              property :type do
                key :type, :string
                key :example, 'claims_api_auto_established_claims_validation'
                key :description, 'Required by JSON API standard'
              end

              property :attributes do
                key :type, :object

                property :status do
                  key :type, :string
                  key :example, 'valid'
                  key :description, 'Return whether or not whether or not the payload is valid'
                end
              end
            end
          end
        end

        response 422 do
          key :description, 'Invalid Payload'
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

    swagger_path '/forms/526/{id}/attachments' do
      operation :post do
        key :summary, 'Upload documents in support of a 526 claim'
        key :description, 'Accpets document binaries as part of a multipart payload.'
        key :operationId, 'upload526Attachments'
        key :produces, [
          'application/json'
        ]
        key :tags, [
          'Disability'
        ]

        parameter do
          key :name, :id
          key :in, :path
          key :description, 'UUID given when Disability Claim was submitted'
          key :required, true
          key :type, :uuid
        end

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
          key :name, 'attachment1'
          key :in, :formData
          key :type, :file
          key :description, 'Attachment contents. Must be provided in PDF format'
        end

        parameter do
          key :name, 'attachment2'
          key :in, :formData
          key :type, :file
          key :description, 'Attachment contents. Must be provided in PDF format'
        end

        response 200 do
          key :description, 'upload response'
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
