# frozen_string_literal: true

module Swagger
  module Requests
    class Form212680
      include Swagger::Blocks

      swagger_schema :Form212680Address do
        key :type, :object
        property :street, type: :string, example: '123 Main St'
        property :street2, type: :string, example: 'Apt 4B'
        property :city, type: :string, example: 'Springfield'
        property :state, type: :string, example: 'IL'
        property :zipCode, type: :string, example: '62701'
        property :country, type: :string, example: 'USA'
      end

      swagger_schema :Form212680FullName do
        key :type, :object
        property :first, type: :string, example: 'John'
        property :middle, type: :string, example: 'A'
        property :last, type: :string, example: 'Doe'
      end

      swagger_path '/v0/form212680/download_pdf' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::UnprocessableEntityError
          extend Swagger::Responses::InternalServerError

          key :description,
              'Generate and download a pre-filled 21-2680 PDF form ' \
              '(Examination for Housebound Status or Permanent Need for Regular Aid and Attendance)'
          key :operationId, 'downloadForm212680Pdf'
          key :tags, %w[benefits_forms]
          key :produces, ['application/pdf']

          parameter do
            key :name, :form212680
            key :in, :body
            key :description, 'Form 21-2680 data for PDF generation'
            key :required, true

            schema do
              key :type, :object

              property :veteranInformation do
                key :type, :object
                key :required, %i[fullName ssn vaFileNumber dateOfBirth]
                key :description, 'Section I: Veteran Information'

                property :fullName do
                  key :$ref, :Form212680FullName
                end
                property :ssn, type: :string, example: '123456789', description: 'Social Security Number (9 digits)'
                property :vaFileNumber, type: :string, example: '987654321', description: 'VA File Number'
                property :dateOfBirth, type: :string, format: :date, example: '1950-01-01', description: 'Date of Birth'
              end

              property :claimantInformation do
                key :type, :object
                key :required, %i[fullName relationship address]
                key :description, 'Section II: Claimant Information'

                property :fullName do
                  key :$ref, :Form212680FullName
                end
                property :relationship, type: :string, example: 'Spouse', description: 'Relationship to veteran'
                property :address do
                  key :$ref, :Form212680Address
                end
              end

              property :benefitInformation do
                key :type, :object
                key :required, %i[claimType]
                key :description, 'Section III: Benefit Information'

                property :claimType, type: :string, example: 'Aid and Attendance',
                                     description: 'Type of claim: "Aid and Attendance" or "Housebound"'
              end

              property :additionalInformation do
                key :type, :object
                key :description, 'Section IV: Additional Information'

                property :currentlyHospitalized, type: :boolean, example: false,
                                                 description: 'Is veteran currently hospitalized?'
                property :nursingHome, type: :boolean, example: false,
                                       description: 'Is veteran in a nursing home?'
              end

              property :veteranSignature do
                key :type, :object
                key :required, %i[signature date]
                key :description, 'Section V: Veteran or Claimant Signature'

                property :signature, type: :string, example: 'John A Doe',
                                     description: 'Signature of veteran or claimant'
                property :date, type: :string, format: :date, example: '2025-10-20',
                                description: 'Date signed (must be within last 60 days)'
              end
            end
          end

          response 200 do
            key :description, 'PDF file successfully generated and ready for download'
            key :schema, type: :file
          end

          response 422 do
            key :description, 'Validation error - form data is incomplete or invalid'
            schema do
              key :type, :object
              property :errors do
                key :type, :array
                items do
                  key :type, :object
                  property :title, type: :string, example: 'Validation error'
                  property :detail, type: :string, example: 'Veteran first name is required'
                  property :code, type: :string, example: '422'
                  property :status, type: :string, example: '422'
                end
              end
            end
          end
        end
      end

      swagger_path '/v0/form212680/submit' do
        operation :post do
          key :description, 'Submit form stub - not yet implemented. Use existing VA document upload system'
          key :operationId, 'submitForm212680'
          key :tags, %w[benefits_forms]

          parameter do
            key :name, :form212680
            key :in, :body
            key :description, 'Form 21-2680 submission data'
            key :required, false

            schema do
              key :type, :object
            end
          end

          response 200 do
            key :description, 'Stub response with instructions'
            schema do
              key :type, :object
              property :message, type: :string,
                                 example: 'Form submission stub - not yet implemented. ' \
                                          'Please use the existing VA document upload system at ' \
                                          'va.gov/upload-supporting-documents'
            end
          end
        end
      end
    end
  end
end
