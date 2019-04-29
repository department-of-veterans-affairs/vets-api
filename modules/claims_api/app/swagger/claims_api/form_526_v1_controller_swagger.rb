# frozen_string_literal: true

module ClaimsApi
  class Form526V1ControllerSwagger
    include Swagger::Blocks

    swagger_path '/form/526' do
      operation :post do
        key :summary, 'Accepts 526 claim form submission'
        key :description, 'Accepts JSON payload. Full URL, including\nquery parameters.'
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

    swagger_path '/form/526/{id}/attachments' do
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

        key :requestBody,
            "content": {
              "multipart/form-data": {
                "schema": {
                  "type": 'object',
                  "properties": {
                    "metadata": {
                      "$ref": '#/components/schemas/SupportingDocument'
                    },
                    "attachment1": {
                      "type": 'string',
                      "example": '<<PDF BINARY>>',
                      "format": 'binary',
                      "description": 'Attachment contents. Must be provided in PDF format'
                    }
                  }
                }
              }
            }

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
