# frozen_string_literal: true

require_dependency 'claims_api/form_schemas'

module ClaimsApi
  module V1
    class Form2122ControllerSwagger
      include Swagger::Blocks

      swagger_path '/forms/2122' do
        operation :get do
          key :summary, 'Get 2122 JSON Schema for form'
          key :description, 'Returns a single 2122 JSON schema to auto generate a form'
          key :operationId, 'get2122JsonSchema'
          key :produces, [
            'application/json'
          ]
          key :tags, [
            'Power of Attorney'
          ]
          security do
            key :bearer_token, []
          end

          response 200 do
            key :description, 'schema response'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :type, :array
                  items do
                    key :type, :object
                    key :description, 'Returning Variety of JSON and UI Schema Objects'
                    key :example, ClaimsApi::FormSchemas.new.schemas['2122']
                  end
                end
              end
            end
          end

          response 401 do
            key :description, 'Unauthorized'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :NotAuthorizedModel
                  end
                end
              end
            end
          end
        end

        operation :post do
          key :summary, 'Accepts 2122 Power of Attorney payload'
          key :description, 'Accepts JSON payload. Full URL, including query parameters.'
          key :operationId, 'post2122'
          key :tags, [
            'Power of Attorney'
          ]

          security do
            key :bearer_token, []
          end

          parameter do
            key :name, 'X-VA-SSN'
            key :in, :header
            key :description, 'SSN of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-EDIPI'
            key :in, :header
            key :description, 'EDIPI Number of Veteran being represented'
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
            key :description, '2122 response'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :'$ref', :Form2122Output
                end
              end
            end
          end

          response 401 do
            key :description, 'Unauthorized'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :NotAuthorizedModel
                  end
                end
              end
            end
          end

          response 422 do
            key :description, 'Unprocessable entity'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :UnprocessableEntityModel
                  end
                end
              end
            end
          end
        end
      end

      swagger_path '/forms/2122/{id}' do
        operation :put do
          key :summary, 'Upload 2122 document'
          key :description, 'Accepts a document binary as part of a multipart payload.'
          key :operationId, 'upload2122Attachment'
          key :produces, [
            'application/json'
          ]
          key :tags, [
            'Power of Attorney'
          ]

          security do
            key :bearer_token, []
          end

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'UUID given when Power of Attorney was submitted'
            key :required, true
            key :type, :uuid
          end

          parameter do
            key :name, 'X-VA-SSN'
            key :in, :header
            key :description, 'SSN of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-EDIPI'
            key :in, :header
            key :description, 'EDIPI Number of Veteran being represented'
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
            key :name, 'attachment'
            key :in, :formData
            key :type, :file
            key :example, 'data:application/pdf;base64,JVBERi0xLjYNJeL...VmDQo0NTc2DQolJUVPRg0K'
            key :description, 'Attachment contents. Must be provided in binary PDF or [base64 string](https://raw.githubusercontent.com/department-of-veterans-affairs/vets-api/master/modules/claims_api/spec/fixtures/base64pdf) format and less than 11 in x 11 in'
          end

          response 200 do
            key :description, '2122 response'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :'$ref', :Form2122Output
                end
              end
            end
          end

          response 401 do
            key :description, 'Unauthorized'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :NotAuthorizedModel
                  end
                end
              end
            end
          end

          response 404 do
            key :description, 'Resource not found'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :NotFoundModel
                  end
                end
              end
            end
          end

          response 422 do
            key :description, 'Unprocessable entity'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :UnprocessableEntityModel
                  end
                end
              end
            end
          end
        end

        operation :get do
          key :summary, 'Check power of attorney status by ID'
          key :description, 'Returns last active JSON payload. Full URL, including\nquery parameters.'
          key :operationId, 'get2122poa'
          key :tags, [
            'Power of Attorney'
          ]

          security do
            key :bearer_token, []
          end

          parameter do
            key :name, 'X-VA-SSN'
            key :in, :header
            key :description, 'SSN of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-EDIPI'
            key :in, :header
            key :description, 'EDIPI Number of Veteran being represented'
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
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :'$ref', :Form2122Output
                end
              end
            end
          end

          response 404 do
            key :description, 'Resource not found'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :NotFoundModel
                  end
                end
              end
            end
          end

          response 401 do
            key :description, 'Unauthorized'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :NotAuthorizedModel
                  end
                end
              end
            end
          end
        end
      end

      swagger_path '/forms/2122/active' do
        operation :get do
          key :summary, 'Check active power of attorney status'
          key :description,
              <<~X
                Returns last active JSON payload.
                * Any authenticated user can view any individual's active, and previous, POA.
              X
          key :operationId, 'getActive2122Poa'
          key :tags, [
            'Power of Attorney'
          ]

          security do
            key :bearer_token, []
          end

          parameter do
            key :name, 'X-VA-SSN'
            key :in, :header
            key :description, 'SSN of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-EDIPI'
            key :in, :header
            key :description, 'EDIPI Number of Veteran being represented'
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
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :'$ref', :Form2122Output
                end
              end
            end
          end

          response 401 do
            key :description, 'Unauthorized'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :NotAuthorizedModel
                  end
                end
              end
            end
          end
        end
      end

      swagger_path '/forms/2122/validate' do
        operation :post do
          key :summary, ' 2122 Power of Attorney form submission dry run'
          key :description, 'Accepts JSON payload.'
          key :operationId, 'validate2122poa'
          key :tags, [
            'Power of Attorney'
          ]

          security do
            key :bearer_token, []
          end

          parameter do
            key :name, 'X-VA-SSN'
            key :in, :header
            key :description, 'SSN of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran being represented'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
            key :required, false
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-EDIPI'
            key :in, :header
            key :description, 'EDIPI Number of Veteran being represented'
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

          request_body do
            key :description, 'JSON API Payload of Veteran requesting POA change'
            key :required, true
            content 'application/json' do
              schema do
                key :'$ref', :Form2122Input
              end
            end
          end

          response 200 do
            key :description, 'Valid'
            content 'application/json' do
              key(
                :examples,
                {
                  default: {
                    value: {
                      data: { type: 'powerOfAttorneyValidation', attributes: { status: 'valid' } }
                    }
                  }
                }
              )
              schema do
                key :type, :object
                property :data do
                  key :type, :object
                  property :type, type: :string
                  property :attributes do
                    key :type, :object
                    property :status, type: :string
                  end
                end
              end
            end
          end

          response 401 do
            key :description, 'Unauthorized'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :NotAuthorizedModel
                  end
                end
              end
            end
          end

          response 422 do
            key :description, 'Unprocessable entity'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :UnprocessableEntityModel
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
