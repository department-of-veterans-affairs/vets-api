# frozen_string_literal: true

require_dependency 'claims_api/form_schemas'

module ClaimsApi
  module V1
    class Form526ControllerSwagger
      include Swagger::Blocks

      swagger_path '/forms/526' do
        operation :get do
          key :summary, 'Get 526 JSON Schema for form'
          key :operationId, 'get526JsonSchema'
          key :description, 'Returns a single 526 JSON schema to auto generate a form'
          key :produces, [
            'application/json'
          ]
          key :tags, [
            'Disability'
          ]

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
                    key :example, ClaimsApi::FormSchemas.new.schemas['526']
                  end
                end
              end
            end
          end

          response :default do
            key :description, 'unexpected error'
            content 'application/json' do
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

        operation :post do
          key :summary, 'Submit form 526'
          key(
            :description,
            <<~X
              Submit [form 526](https://www.vba.va.gov/pubs/forms/VBA-21-526EZ-ARE.pdf).
              Takes in JSON, returns UUID for submission. Asynchronously auto-establishes claim and generates a PDF for VBMS.
              Can accept document binary PDF or base64 string as part of a multi-part payload (as `attachment1`, `attachment2`, etc.).
              **If you are filing an original claim, and the filer is not the veteran** (the oauth token is not the veteran’s), see [PUT /forms/526/{id}](#operations-Disability-upload526Attachment).
            X
          )
          key :operationId, 'post526Claim'
          key :tags, [
            'Disability'
          ]

          security do
            key :apikey, []
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

          request_body do
            key :description, 'JSON API Payload of Veteran being submitted'
            key :required, true
            content 'application/json' do
              schema do
                key :'$ref', :Form526Input
              end
            end
          end

          response 200 do
            key :description, '526 response'
            content 'application/json' do
              schema do
                key :'$ref', :ClaimsIndex
              end
            end
          end
          response :default do
            key :description, 'unexpected error'
            content 'application/json' do
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

      swagger_path '/forms/526/{id}' do
        operation :put do
          key :summary, 'Upload 526 document'
          key(
            :description,
            <<~X
              Upload attachments for [form 526](https://www.vba.va.gov/pubs/forms/VBA-21-526EZ-ARE.pdf) submission.
              Use this endpoint in conjunction with the [POST](#operations-Disability-post526Claim) endpoint to file an original claim when the filer is _not_ the veteran (the oauth token is not the veteran’s).
              In most cases, if the veteran is not the filer on the original claim, a scanned copy of form 526, signed in ink by the veteran, is required.
              **`Step 1:`** use [POST /forms/526/{id}](#operations-Disability-post526Claim) but set `"autoCestPDFGenerationDisabled": true` (this disables automatic PDF generation).
              **`Step 2:`** use PUT to attach scan of form 526 in binary PDF or base64 string.
            X
          )
          key :operationId, 'upload526Attachment'
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
            key :name, 'attachment'
            key :in, :formData
            key :type, :file
            key :description, 'Attachment contents. Must be provided in binary PDF or base64 string format and less than 11 in x 11 in'
          end

          response 200 do
            key :description, '526 response'
            content 'application/json' do
              schema do
                key :'$ref', :ClaimsIndex
              end
            end
          end

          response :default do
            key :description, 'unexpected error'
            content 'application/json' do
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

      swagger_path '/forms/526/validate' do
        operation :post do
          key :summary, 'Validates a 526 claim form submission'
          key :operationId, 'post526ClaimValidate'
          key :tags, [
            'Disability'
          ]

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
            content 'application/json' do
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
          end

          response 422 do
            key :description, 'Invalid Payload'
            content 'application/json' do
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

          response :default do
            key :description, 'unexpected error'
            content 'application/json' do
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

      swagger_path '/forms/526/{id}/attachments' do
        operation :post do
          key :summary, 'Upload documents in support of a 526 claim'
          key :description, 'Accpets document binary PDF or base64 string as part of a multipart payload. Accepts N number of attachments, via attachment1 .. attachmentN'
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
            key :description, 'Attachment contents. Must be provided in binary PDF or base64 string format and less than 11 in x 11 in'
          end

          parameter do
            key :name, 'attachment2'
            key :in, :formData
            key :type, :file
            key :description, 'Attachment contents. Must be provided in binary PDF or base64 string format and less than 11 in x 11 in'
          end

          response 200 do
            key :description, 'upload response'
          end
          response :default do
            key :description, 'unexpected error'
            content 'application/json' do
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
end
