# frozen_string_literal: true

module Swagger
  module Requests
    class Coe
      include Swagger::Blocks

      swagger_path '/v0/coe/status' do
        operation :get do
          key :description, 'Returns the status of a vet\'s Certificate of Eligibility application.'
          key :operationId, 'coeGetCoeStatus'
          key :tags, %w[coe]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK. Possible statuses:
            - ELIGIBLE: vet is automatically enrolled in a COE.
            - UNABLE_TO_DETERMINE_AUTOMATICALLY: vet must complete the COE form.
            - AVAILABLE: vet has filled out the COE form and it is available for download.
            - DENIED: means that the vet submitted a COE form but it was denied.
            - PENDING: vet submitted a COE form but it is still being reviewed.
            - PENDING_UPLOAD: vet submitted a COE form but must upload more supporting documents to be granted a COE.
            A reference_number is always returned.
            An application_create_date is returned unless the COE application is ELIGIBLE or PENDING.
            '
            schema do
              property :data do
                property :attributes do
                  property :status, type: :string, enum: %w[
                    ELIGIBLE
                    UNABLE_TO_DETERMINE_AUTOMATICALLY
                    AVAILABLE
                    DENIED
                    PENDING
                    PENDING_UPLOAD
                  ], example: 'UNABLE_TO_DETERMINE_AUTOMATICALLY'
                  property :referenceNumber, type: :string, example: '17923279'
                  property :applicationCreateDate, type: :integer, example: 1_668_447_149_000
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/coe/download_coe' do
        operation :get do
          key :description, 'Downloads Certificate of Eligiblity application as PDF'
          key :operationId, 'coeDownloadCoe'
          key :tags, %w[coe]
          key :produces, ['application/pdf']

          parameter :authorization

          response 200 do
            key :description, 'Response is OK.'
          end
        end
      end

      swagger_path '/v0/coe/documents' do
        operation :get do
          key :description, %(Retrieves a list of supporting documents that the
            vet attached to their COE application. The `id` is used to fetch documents
            via the `/vo/coe/document_download/{id}` endpoint below. The `mimeType`
            is, unfortunately, the filename from which the front end pulls the file
            extension. The `documentType` will either be "Veteran Correspondence"
            (meaning, a document uploaded by the veteran during the COE form) or
            the "kind" of notification letter (e.g. "COE Application First Returned").
            By the time you read this, the `description` will probably be a description
            of any "Veteran Correspondence." Notification letters should not have a
            `description`.
          ).gsub("\n", ' ')
          key :operationId, 'coeDocuments'
          key :tags, %w[coe]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK.'

            schema do
              property :data do
                property :attributes do
                  key :type, :array
                  items do
                    key :type, :object
                    property :id, type: :integer, example: 23_924_541
                    property :documentType, type: :string, example: 'COE Application First Returned'
                    property :description, type: [:string, 'null'], example: 'null'
                    property :mimeType, type: :string, example: 'COE Application First Returned.pdf'
                    property :createDate, type: :integer, example: 1_664_222_568_000
                  end
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/coe/document_download/{id}' do
        operation :get do
          key :description, 'Downloads supporting document with specified ID.'
          key :operationId, 'coeDocumentDownload'
          key :tags, %w[coe]
          key :produces, ['application/pdf']

          parameter :authorization

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'The ID of the supporting document.'
            key :required, true
            key :type, :integer
          end

          response 200 do
            key :description, 'Response is OK.'
          end
        end
      end

      swagger_path '/v0/coe/submit_coe_claim' do
        operation :post do
          key :description, 'Saves form data and submits it to LGY.'
          key :operationId, 'coeSubmitCoeClaim'
          key :tags, %w[coe]

          parameter :authorization

          parameter do
            key :name, :lgy_coe_claim
            key :in, :body
            key :description, 'Form data as a json string.'
            key :required, true

            schema do
              property :lgy_coe_claim do
                property :form do
                  key :type, :string
                end
              end
              example do
                key :form, {
                  'files' =>
                  [{
                    'name' => 'Example.pdf',
                    'size' => 60_217,
                    'confirmationCode' => 'a7b6004e-9a61-4e94-b126-518ec9ec9ad0',
                    'isEncrypted' => false,
                    'attachmentType' => 'Discharge or separation papers (DD214)'
                  }],
                  'relevantPriorLoans' => [{
                    'dateRange' => {
                      'from' => '2002-05-01T00:00:00.000Z',
                      'to' => '2003-01-01T00:00:00.000Z'
                    },
                    'propertyAddress' => {
                      'propertyAddress1' => '123 Faker St',
                      'propertyAddress2' => '2',
                      'propertyCity' => 'Fake City',
                      'propertyState' => 'AL',
                      'propertyZip' => '11111'
                    },
                    'vaLoanNumber' => '111222333444',
                    'propertyOwned' => true,
                    'intent' => 'ONETIMERESTORATION'
                  }],
                  'vaLoanIndicator' => true,
                  'periodsOfService' => [{
                    'serviceBranch' => 'Air National Guard',
                    'dateRange' => {
                      'from' => '2001-01-01T00:00:00.000Z',
                      'to' => '2002-02-02T00:00:00.000Z'
                    }
                  }],
                  'identity' => 'ADSM',
                  'contactPhone' => '2222222222',
                  'contactEmail' => 'veteran@example.com',
                  'applicantAddress' => {
                    'country' => 'USA',
                    'street' => '140 FAKER ST',
                    'street2' => '2',
                    'city' => 'FAKE CITY',
                    'state' => 'MT',
                    'postalCode' => '80129'
                  },
                  'fullName' => {
                    'first' => 'Alexander',
                    'middle' => 'Guy',
                    'last' => 'Cook',
                    'suffix' => 'Jr.'
                  },
                  'dateOfBirth' => '1950-01-01',
                  'privacyAgreementAccepted' => true
                }.to_json
              end
            end
          end

          response 200 do
            key :description, 'Form submitted successfully.'
            schema do
              property :data do
                property :attributes do
                  property :claim do
                    property :createdAt, type: :string, format: :'date-time'
                    property :encryptedKmsKey, type: :string
                    property :formId, type: :string
                    property :guid, type: :string, format: :uuid
                    property :id, type: :integer
                    property :updatedAt, type: :string, format: :'date-time'
                    property :verifiedDecryptableAt, type: :string, format: :'date-time'
                  end
                  property :referenceNumber
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/coe/document_upload' do
        operation :post do
          key :description, 'Upload supporting documents'
          key :operationId, 'coeDocumentUpload'
          key :tags, %w[coe]
          key :consumes, %w[multipart/form-data]

          parameter :authorization

          parameter do
            key :name, :files
            key :in, :body
            key :description, 'File data'
            key :required, true
            schema do
              key :type, :array
              items do
                key :type, :object
                property :file, type: :string, format: :binary, example: '(binary)'
                property :document_type, type: :string, example: 'VA home loan documents'
                property :file_type, type: :string, example: 'pdf'
                property :file_name, type: :string, example: 'example.pdf'
              end
            end
          end

          response 200 do
            key :description, 'Files uploaded successfully'
          end
        end
      end
    end
  end
end
