# frozen_string_literal: true

require_dependency 'claims_api/form_schemas'

module ClaimsApi
  module V0
    class Form2122ControllerSwagger
      include Swagger::Blocks

      swagger_path '/forms/2122' do
        operation :get do
          security do
            key :apikey, []
          end
          key :summary, 'Gets schema for POA form.'
          key :description, 'Returns schema to automatically generate a POA form.'
          key :operationId, 'get2122JsonSchema'
          key :produces, [
            'application/json'
          ]
          key :tags, [
            'Power of Attorney'
          ]

          parameter do
            key :name, 'apikey'
            key :in, :header
            key :description, 'API Key given to access data'
            key :required, true
            key :type, :string
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
                    key :$ref, :NotAuthorizedModel
                  end
                end
              end
            end
          end
        end

        operation :post do
          security do
            key :apikey, []
          end
          key :summary, 'Submit a POA form.'
          key(
            :description,
            <<~X
              The endpoint establishes POA for a representative. The following is required:
               - poaCode
               - POA first name
               - POA last name
               - Signature, which can be a:
                 - Base64-encoded image or signature block, allowing the API to auto-populate and attach the VA 21-22 form to the request without requiring a PDF upload, or
                 - PDF documentation of VA 21-22 form with an ink signature, attached using the PUT /forms/2122/{id} endpoint

              A 200 response means the submission was successful, but does not mean the POA is effective. Check the status of a POA submission by using the GET /forms/2122/{id} endpoint.
            X
          )
          key :operationId, 'post2122poa'
          key :tags, [
            'Power of Attorney'
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
            key :description, 'SSN of Veteran being represented'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran being represented'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran being represented'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
            key :required, true
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
                key :$ref, :Form2122Input
              end
            end
          end

          response 200 do
            key :description, '0966 response'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :$ref, :Form2122Output
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
                    key :$ref, :NotAuthorizedModel
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
                    key :$ref, :UnprocessableEntityModel
                  end
                end
              end
            end
          end
        end
      end

      swagger_path '/forms/2122/{id}' do
        operation :put do
          security do
            key :apikey, []
          end
          key :summary, 'Upload a signed 21-22 document.'
          key(
            :description,
            <<~X
              Accepts a document binary as part of a multipart payload. Use this PUT endpoint after the POST endpoint for uploading the signed 21-22 PDF form.
            X
          )
          key :operationId, 'upload2122Attachments'
          key :produces, [
            'application/json'
          ]
          key :tags, [
            'Power of Attorney'
          ]

          parameter do
            key :name, 'apikey'
            key :in, :header
            key :description, 'API Key given to access data'
            key :required, true
            key :type, :string
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
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran being represented'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran being represented'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
            key :required, true
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
                  key :$ref, :Form2122Output
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
                    key :$ref, :NotAuthorizedModel
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
                    key :$ref, :NotFoundModel
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
                    key :$ref, :UnprocessableEntityModel
                  end
                end
              end
            end
          end
        end

        operation :get do
          security do
            key :apikey, []
          end
          key :summary, 'Check POA status by ID.'
          key :description, 'Based on ID, returns a 21-22 submission and current status.'
          key :operationId, 'get2122poa'
          key :tags, [
            'Power of Attorney'
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
            key :description, 'SSN of Veteran being represented'
            key :example, '796130115'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran being represented'
            key :example, 'Tamara'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran being represented'
            key :example, 'Ellis'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
            key :example, '1967-06-19'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-User'
            key :in, :header
            key :description, 'VA username of the person making the request'
            key :example, 'lighthouse'
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
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :$ref, :Form2122Output
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
                    key :$ref, :NotAuthorizedModel
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
                    key :$ref, :NotFoundModel
                  end
                end
              end
            end
          end
        end
      end

      swagger_path '/forms/2122/active' do
        operation :get do
          security do
            key :apikey, []
          end
          key :summary, 'Check active POA status.'
          key(
            :description,
            <<~X
              Returns the last active POA for a Veteran. To check the status of new POA submissions, use the GET /forms/2122/{id} endpoint.
            X
          )
          key :operationId, 'getActive2122Poa'
          key :tags, [
            'Power of Attorney'
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
            key :description, 'SSN of Veteran being represented'
            key :required, true
            key :example, '796130115'
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran being represented'
            key :example, 'Tamara'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran being represented'
            key :example, 'Ellis'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
            key :example, '1967-06-19'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-User'
            key :in, :header
            key :description, 'VA username of the person making the request'
            key :example, 'lighthouse'
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
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :$ref, :Form2122NoPreviousPOAOutput
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
                    key :$ref, :NotAuthorizedModel
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
                    key :$ref, :NoPOAFound
                  end
                end
              end
            end
          end
        end
      end

      swagger_path '/forms/2122/validate' do
        operation :post do
          security do
            key :apikey, []
          end
          key :summary, '21-22 POA form submission test run.'
          key :description, 'Test to make sure the form submission works with your parameters.'
          key :operationId, 'validate2122poa'
          key :tags, [
            'Power of Attorney'
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
            key :description, 'SSN of Veteran being represented'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-First-Name'
            key :in, :header
            key :description, 'First Name of Veteran being represented'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Last-Name'
            key :in, :header
            key :description, 'Last Name of Veteran being represented'
            key :required, true
            key :type, :string
          end

          parameter do
            key :name, 'X-VA-Birth-Date'
            key :in, :header
            key :description, 'Date of Birth of Veteran being represented, in iso8601 format'
            key :required, true
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
            key :description, 'JSON API Payload of Veteran requesting POA change'
            key :required, true
            content 'application/json' do
              schema do
                key :$ref, :Form2122Input
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
                    key :$ref, :NotAuthorizedModel
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
                    key :$ref, :UnprocessableEntityModel
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
