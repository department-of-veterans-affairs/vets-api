# frozen_string_literal: true

module Swagger
  module Requests
    class Form210779
      include Swagger::Blocks

      swagger_path '/v0/form210779' do
        operation :post do
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::SavedForm
          extend Swagger::Responses::ForbiddenError

          key :description,
              'Submit a 21-0779 form (Request for Nursing Home Information in Connection with Claim for ' \
              'Aid and Attendance)'
          key :operationId, 'submitForm210779'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :form210779
            key :in, :body
            key :description, 'Form 21-0779 submission data'
            key :required, true

            schema do
              key :type, :object

              property :veteranInformation do
                key :type, :object
                key :required, %i[first last dateOfBirth veteranId]

                property :first, type: :string, example: 'John'
                property :middle, type: :string, example: 'A'
                property :last, type: :string, example: 'Doe'
                property :dateOfBirth, type: :string, format: :date, example: '1990-01-01'
                property :veteranId do
                  key :type, :object
                  property :ssn, type: :string, example: '123456789'
                  property :vaFileNumber, type: :string, example: '987654321'
                end
              end

              property :claimantInformation do
                key :type, :object
                key :required, %i[first last dateOfBirth veteranId]

                property :first, type: :string, example: 'Jane'
                property :middle, type: :string, example: 'B'
                property :last, type: :string, example: 'Doe'
                property :dateOfBirth, type: :string, format: :date, example: '1992-05-15'
                property :veteranId do
                  key :type, :object
                  property :ssn, type: :string, example: '987654321'
                  property :vaFileNumber, type: :string, example: '123456789'
                end
              end

              property :nursingHomeInformation do
                key :type, :object
                key :required, %i[nursingHomeName nursingHomeAddress]

                property :nursingHomeName, type: :string, example: 'Sunrise Senior Living'
                property :nursingHomeAddress do
                  key :type, :object
                  key :required, %i[street city state country postalCode]

                  property :street, type: :string, example: '123 Care Lane'
                  property :street2, type: :string, example: 'Building A'
                  property :city, type: :string, example: 'Springfield'
                  property :state, type: :string, example: 'IL'
                  property :country, type: :string, example: 'USA'
                  property :postalCode, type: :string, example: '62701'
                end
              end

              property :generalInformation do
                key :type, :object
                key :required,
                    %i[
                      admissionDate medicaidFacility medicaidApplication
                      patientMedicaidCovered certificationLevelOfCare
                      nursingOfficialName nursingOfficialTitle
                      nursingOfficialPhoneNumber
                    ]

                property :admissionDate, type: :string, format: :date, example: '2024-01-01'
                property :medicaidFacility, type: :boolean, example: true
                property :medicaidApplication, type: :boolean, example: true
                property :patientMedicaidCovered, type: :boolean, example: true
                property :medicaidStartDate, type: :string, format: :date, example: '2024-02-01'
                property :monthlyCosts, type: :string, example: '3000.00'
                property :certificationLevelOfCare, type: :boolean, example: true
                property :nursingOfficialName, type: :string, example: 'Dr. Sarah Smith'
                property :nursingOfficialTitle, type: :string, example: 'Director of Nursing'
                property :nursingOfficialPhoneNumber, type: :string, example: '555-789-0123'
              end
            end
          end

          response 200 do
            key :description, 'Form successfully submitted'
            schema do
              key :$ref, :SavedForm
            end
          end

          response 403 do
            key :description, 'Feature flag disabled - user does not have access to digital form'
          end

          response 422 do
            key :description, 'Validation error - missing or invalid required fields'
          end
        end
      end

      swagger_path '/v0/form210779/download_pdf' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Download a pre-filled 21-0779 PDF form'
          key :operationId, 'downloadForm210779Pdf'
          key :tags, %w[benefits_forms]

          parameter :optional_authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Form data for PDF generation'
            key :required, true

            schema do
              key :type, :string
              key :description, 'JSON string of form data'
            end
          end

          response 200 do
            key :description, 'PDF file download'
            key :produces, ['application/pdf']
          end

          response 403 do
            key :description, 'Feature flag disabled'
          end
        end
      end
    end
  end
end
