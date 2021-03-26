# frozen_string_literal: true

require_dependency 'claims_api/form_schemas'

module ClaimsApi
  module V0
    class Form526ControllerSwagger
      include Swagger::Blocks

      swagger_path '/forms/526' do
        operation :get do
          security do
            key :apikey, []
          end
          key :summary, 'Get a 526 schema for a claim.'
          key :description, 'Returns a single 526 schema to automatically generate a form. Using this GET endpoint allows users to download our current validations.'
          key :operationId, 'get526JsonSchema'
          key :produces, [
            'application/json'
          ]
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
          key :summary, 'Submit form 526.'
          key(
            :description,
            <<~X
              Establishes a [Disability Compensation Claim](https://www.vba.va.gov/pubs/forms/VBA-21-526EZ-ARE.pdf) in VBMS. Submits any PDF attachments as a multi-part payload and returns an ID. For claims that are not original claims, this endpoint generates a filled 526 PDF along with the submission.
              <br/><br/>
              A 200 response indicates the submission was successful, but the claim has not reached VBMS until it has a “claim established” status. Check claim status using the GET /claims/{id} endpoint.
              <br/><br/>
              **Original claims**<br/>
              An original claim is the Veteran’s first claim filed with VA, regardless of the claim type or status. The original claim must have the Veteran’s wet signature. Once there is an original claim on file, future claims may be submitted by a representative without the Veteran’s wet signature. Uploading a PDF for subsequent claims is not required or recommended.
              <br/><br/>
              POST the original claim with the autoCestPDFGenerationDisabled boolean as true. After a 200 response, use the PUT /forms/526/{id} endpoint to upload a scanned PDF of your form, signed in ink, by the Veteran.
              <br/><br/>
              The claim data submitted through the POST endpoint must match the wet-signed PDF uploaded through the PUT endpoint. If it does not, VA will manually update the data to match the PDF, and your claim may not process correctly.
              <br/><br/>
              **Standard and fully developed claims (FDCs)**<br/>
              [Fully developed claims (FDCs)](https://www.va.gov/disability/how-to-file-claim/evidence-needed/fully-developed-claims/) are claims certified by the submitter to include all information needed for processing. These claims process faster than claims submitted through the standard claim process. If a claim is certified for the FDC, but is missing needed information, it will route through the standard claim process.
              <br/><br/>
              To certify a claim for the FDC process, set the standardClaim indicator to false.
              <br/><br/>
              **Flashes and special issues**<br/>
              Including flashes and special issues in your 526 claim submission helps VA properly route and prioritize current and future claims for the Veteran and reduces claims processing time.

               - Flashes are attributes that describe special circumstances which apply to a Veteran, such as homelessness or terminal illness. See a full list of [supported flashes](https://github.com/department-of-veterans-affairs/vets-api/blob/30659c8e5b2dd254d3e6b5d18849ff0d5f2e2356/modules/claims_api/config/schemas/526.json#L35).
               - Special Issues are attributes that describe special circumstances which apply to a particular claim, such as PTSD. See a full list of [supported special Issues](https://github.com/department-of-veterans-affairs/vets-api/blob/30659c8e5b2dd254d3e6b5d18849ff0d5f2e2356/modules/claims_api/config/schemas/526.json#L28).
            X
          )
          key :operationId, 'post526Claim'
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
                key :$ref, :Form526Input
              end
            end
          end

          response 200 do
            key :description, '526 response'
            content 'application/json' do
              schema do
                key :$ref, :ClaimsIndex
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

      swagger_path '/forms/526/{id}' do
        operation :put do
          security do
            key :apikey, []
          end
          key :summary, 'Upload a 526 document.'
          key(
            :description,
            <<~X
              Used to upload a completed, wet-signed 526 PDF to establish an original claim. Use this endpoint only after following the instructions in the POST /forms/526 endpoint to begin the claim submission.
              <br/><br/>
              This endpoint works by accepting a document binary PDF as part of a multi-part payload (for example, attachment1, attachment2, attachment3). Each attachment should be encoded separately rather than encoding the whole payload together as with the Benefits Intake API.
              <br/><br/>
              For other attachments, such as medical records, use the /forms/526/{id}/attachments endpoint.
            X
          )
          key :operationId, 'upload526Doc'
          key :produces, [
            'application/json'
          ]
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
            key :description, '526 response'
            content 'application/json' do
              schema do
                key :$ref, :ClaimsIndex
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
      end

      swagger_path '/forms/526/validate' do
        operation :post do
          security do
            key :apikey, []
          end
          key :summary, 'Validates a 526 claim form submission.'
          key :description, 'Test to make sure the form submission works with your parameters. Submission validates against the schema returned by the GET /forms/526 endpoint.'
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
            key :name, 'payload'
            key :in, :body
            key :description, 'JSON API Payload of Veteran being submitted'
            key :required, true
            content 'application/json' do
              schema do
                key :$ref, :Form526Input
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

      swagger_path '/forms/526/{id}/attachments' do
        operation :post do
          security do
            key :apikey, []
          end
          key :summary, 'Upload documents supporting a 526 claim.'
          key(
            :description,
            <<~X
              Used to attach supporting documents for a 526 claim. For wet-signature PDFs, use the PUT /forms/526/{id} endpoint.
              <br/><br/>
              This endpoint accepts a document binary PDF as part of a multi-part payload (for example, attachment1, attachment2, attachment3).
            X
          )
          key :operationId, 'upload526Attachments'
          key :produces, [
            'application/json'
          ]
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
                  key :$ref, :ClaimsShow
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
      end
    end
  end
end
