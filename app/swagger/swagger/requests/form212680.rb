# frozen_string_literal: true

module Swagger
  module Requests
    class Form212680
      include Swagger::Blocks

      swagger_schema :Form212680FullName do
        key :type, :object
        property :first, type: :string, example: 'John'
        property :middle, type: :string, example: 'A'
        property :last, type: :string, example: 'Doe'
      end

      swagger_schema :Form212680Address do
        key :type, :object
        property :street, type: :string, example: '123 Main St'
        property :city, type: :string, example: 'Anytown'
        property :state, type: :string, example: 'CA'
        property :zipCode, type: :string, example: '12345'
      end

      swagger_path '/v0/form212680/download_pdf' do
        operation :post do
          key :description, 'Generate a pre-filled 21-2680 PDF form'
          key :operationId, 'downloadForm212680Pdf'
          key :tags, %w[benefits_forms]

          parameter do
            key :name, :form212680
            key :in, :body
            key :description, 'Form 21-2680 data for PDF generation'
            key :required, true

            schema do
              key :type, :object

              property :veteranInformation do
                key :type, :object
                key :required, %i[fullName ssn dateOfBirth]

                property :fullName do
                  key :$ref, :Form212680FullName
                  key :required, %i[first last]
                end
                property :ssn, type: :string, example: '123456789'
                property :vaFileNumber, type: :string, example: '987654321'
                property :dateOfBirth, type: :string, format: :date, example: '1990-01-01'
              end

              property :claimantInformation do
                key :type, :object
                key :required, %i[fullName relationship address]

                property :fullName do
                  key :$ref, :Form212680FullName
                  key :required, %i[first last]
                end
                property :relationship, type: :string, example: 'Spouse'
                property :address do
                  key :$ref, :Form212680Address
                  key :required, %i[street city state zipCode]
                end
              end

              property :benefitInformation do
                key :type, :object
                key :required, %i[claimType]

                property :claimType, type: :string, example: 'Aid and Attendance'
              end

              property :additionalInformation do
                key :type, :object

                property :currentlyHospitalized, type: :boolean, example: false
                property :nursingHome, type: :boolean, example: false
              end

              property :veteranSignature do
                key :type, :object
                key :required, %i[signature date]

                property :signature, type: :string, example: 'John A Doe'
                property :date, type: :string, format: :date, example: '2025-10-01'
              end
            end
          end

          response 200 do
            key :description, 'PDF generation instructions'
            schema do
              key :type, :object
              property :message, type: :string, example: 'PDF generation stub - not yet implemented'
              property :instructions do
                key :type, :object
                property :title, type: :string, example: 'Next Steps: Get Physician to Complete Form'
                property :steps, type: :array, items: { type: :string }
                property :upload_url, type: :string, example: 'https://va.gov/upload-supporting-documents'
                property :form_number, type: :string, example: '21-2680'
                property :regional_office, type: :string,
                                           example: 'Department of Veterans Affairs, Pension Management Center,' \
                                                    'P.O. Box 5365, Janesville, WI 53547-5365'
              end
            end
          end
        end
      end
    end
  end
end
