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
                    key :example, ClaimsApi::FormSchemas.new.schemas['526']
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
          key :summary, 'Submit form 526'
          key(
            :description,
            <<~X
              Submit [form 526](https://www.vba.va.gov/pubs/forms/VBA-21-526EZ-ARE.pdf).
              Takes in JSON, returns UUID for submission. Asynchronously auto-establishes claim and generates a PDF for VBMS.
              Can accept document binary PDF or base64 string as part of a multi-part payload (as `attachment1`, `attachment2`, etc.).
              **If you are filing an original claim, and the filer is not the veteran** (the oauth token is not the veteran’s), see [PUT /forms/526/{id}](#operations-Disability-upload526Attachment).

              * Claim establishment is handled asynchronously. See [GET /claims/{id}](#operations-Claims-findClaimById) to check status of submission.
              * Claim establishment does not start if autoCestPDFGenerationDisabled is set to true. [PUT /forms/526/{id}](#operations-Disability-upload526Attachment) is required to begin establishing the claim.
            X
          )
          key :operationId, 'post526Claim'
          key :tags, [
            'Disability'
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
                key :'$ref', :Form526Input
              end
            end
          end

          response 200 do
            key :description, '526 response'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :'$ref', :Form526Response
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

      swagger_path '/forms/526/{id}' do
        operation :put do
          key :summary, 'Upload 526 document'
          key(
            :description,
            <<~X
              Use this endpoint to upload completed, wet-signed 526 PDFs after POSTing the claim data to
              the [/forms/526](#operations-Disability-post526Claim) endpoint. Uploading a completed, wet-signed
              PDF is only required for a Veteran's first claim (called an original claim) when the original claim
              is filed by a representative using the representative's OAuth token. Uploading a PDF for subsequent
              claims is not required or recommended. When using this endpoint, you must:

              * Set the `autoCestPDFGenerationDisabled` boolean in your [/forms/526](#operations-Disability-post526Claim)
              payload to `true` (unless explicitly set, a PDF is automatically generated using the data submitted in
              the original 526 submission payload).

              * Send only [526 forms](https://www.vba.va.gov/pubs/forms/VBA-21-526EZ-ARE.pdf). For other attachments,
              such as medical records, use the
              [/forms/526/{id}/attachments](#operations-Disability-upload526Attachments) endpoint.

              * The pdf you are sending represents the final version of the claim that was submitted through
              the POST to [/forms/526](#operations-Disability-post526Claim). If there is a discrepancy between the
              PDF and the data submitted through the [/forms/526](#operations-Disability-post526Claim) endpoint,
              the VA will manually review the data and change it to the values present in the PDF.
            X
          )
          key :operationId, 'upload526Attachment'
          key :produces, [
            'application/json'
          ]
          key :tags, [
            'Disability'
          ]

          security do
            key :bearer_token, []
          end

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
            key :description, '526 response'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :'$ref', :ClaimsIndex
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
      end

      swagger_path '/forms/526/validate' do
        operation :post do
          key :summary, 'Validates a 526 claim form submission'
          key :operationId, 'post526ClaimValidate'
          key :tags, [
            'Disability'
          ]

          security do
            key :bearer_token, []
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
            key :required, true
            key :type, :string
          end

          request_body do
            key :name, 'payload'
            key :in, :body
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

          security do
            key :bearer_token, []
          end

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
            key :name, 'attachment1'
            key :in, :formData
            key :type, :file
            key :example, 'data:application/pdf;base64,JVBERi0xLjYNJeL...VmDQo0NTc2DQolJUVPRg0K'
            key :description, 'Attachment contents. Must be provided in binary PDF or [base64 string](https://raw.githubusercontent.com/department-of-veterans-affairs/vets-api/master/modules/claims_api/spec/fixtures/base64pdf) format and less than 11 in x 11 in'
          end

          parameter do
            key :name, 'attachment2'
            key :in, :formData
            key :type, :file
            key :example, 'data:application/pdf;base64,JVBERi0xLjYNJeL...VmDQo0NTc2DQolJUVPRg0K'
            key :description, 'Attachment contents. Must be provided in binary PDF or [base64 string](https://raw.githubusercontent.com/department-of-veterans-affairs/vets-api/master/modules/claims_api/spec/fixtures/base64pdf) format and less than 11 in x 11 in'
          end

          response 200 do
            key :description, 'upload response'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :'$ref', :ClaimsShow
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
      end
    end
  end
end
