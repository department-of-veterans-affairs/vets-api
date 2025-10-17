# frozen_string_literal: true

module Swagger
  module Requests
    class Form21p530a
      include Swagger::Blocks

      swagger_schema :Form21p530aFullName do
        key :type, :object
        property :first, type: :string, example: 'John'
        property :middle, type: :string, example: 'M'
        property :last, type: :string, example: 'Doe'
        property :suffix, type: :string, example: 'Jr'
      end

      swagger_schema :Form21p530aPlaceOfBirth do
        key :type, :object
        property :city, type: :string, example: 'Springfield'
        property :state, type: :string, example: 'IL'
        property :country, type: :string, example: 'USA'
      end

      swagger_schema :Form21p530aServicePeriod do
        key :type, :object
        property :serviceBranch, type: :string, example: 'Army'
        property :dateEnteredService, type: :string, format: :date, example: '1960-01-15'
        property :placeEnteredService, type: :string, example: 'Fort Benning, GA'
        property :rankAtSeparation, type: :string, example: 'E-5'
        property :dateLeftService, type: :string, format: :date, example: '1965-12-31'
        property :placeLeftService, type: :string, example: 'Fort Hood, TX'
      end

      swagger_schema :Form21p530aServiceUnderOtherName do
        key :type, :object
        property :used, type: :boolean, example: false
        property :fullName do
          key :$ref, :Form21p530aFullName
        end
        property :serviceRendered, type: :string, example: 'Army, 1960-1965'
      end

      swagger_schema :Form21p530aCemeteryLocation do
        key :type, :object
        property :street, type: :string, example: '1000 Memorial Drive'
        property :city, type: :string, example: 'Springfield'
        property :state, type: :string, example: 'IL'
        property :postalCode, type: :string, example: '62701'
      end

      swagger_schema :Form21p530aPlaceOfBurial do
        key :type, :object
        property :cemeteryName, type: :string, example: 'Springfield Veterans Cemetery'
        property :cemeteryLocation do
          key :$ref, :Form21p530aCemeteryLocation
        end
      end

      swagger_schema :Form21p530aOrganizationAddress do
        key :type, :object
        property :street, type: :string, example: '401 Capitol Ave'
        property :street2, type: :string, example: 'Suite 100'
        property :city, type: :string, example: 'Springfield'
        property :state, type: :string, example: 'IL'
        property :postalCode, type: :string, example: '62701'
        property :country, type: :string, example: 'USA'
      end

      swagger_path '/v0/form21p530a' do
        operation :post do
          extend Swagger::Responses::SavedForm

          key :description,
              'Submit a 21P-530a form (Application for Burial Allowance - State/Tribal Organizations)'
          key :operationId, 'submitForm21p530a'
          key :tags, %w[benefits_forms]

          parameter do
            key :name, :form21p530a
            key :in, :body
            key :description, 'Form 21P-530a submission data'
            key :required, true

            schema do
              key :type, :object

              property :veteranFullName do
                key :$ref, :Form21p530aFullName
                key :required, %i[first last]
              end
              property :veteranSocialSecurityNumber, type: :string, example: '123456789'
              property :veteranServiceNumber, type: :string, example: 'RA12345678'
              property :vaFileNumber, type: :string, example: '987654321'
              property :veteranDateOfBirth, type: :string, format: :date, example: '1940-05-15'
              property :placeOfBirth do
                key :$ref, :Form21p530aPlaceOfBirth
              end
              property :deathDate, type: :string, format: :date, example: '2023-12-01'

              property :servicePeriods do
                key :type, :array
                items do
                  key :$ref, :Form21p530aServicePeriod
                end
              end

              property :serviceUnderOtherName do
                key :$ref, :Form21p530aServiceUnderOtherName
              end

              property :cemeteryOrganizationName,
                       type: :string,
                       example: 'Illinois Department of Veterans Affairs'
              property :placeOfBurial do
                key :$ref, :Form21p530aPlaceOfBurial
              end
              property :burialDate, type: :string, format: :date, example: '2023-12-05'
              property :recipientOrganizationName,
                       type: :string,
                       example: 'Illinois Department of Veterans Affairs'
              property :recipientOrganizationPhoneNumber, type: :string, example: '217-555-0123'
              property :recipientOrganizationContactEmail, type: :string, example: 'burials@illinois.gov'
              property :recipientOrganizationAddress do
                key :$ref, :Form21p530aOrganizationAddress
              end
              property :certificationSignature, type: :string, example: 'Jane Smith'
              property :certificationTitle, type: :string, example: 'Cemetery Director'
              property :certificationDate, type: :string, format: :date, example: '2024-01-15'
              property :remarks, type: :string, example: 'Veteran served honorably during Vietnam War'
            end
          end

          response 200 do
            key :description, 'Form successfully submitted'
            schema do
              key :$ref, :SavedForm
            end
          end
        end
      end

      swagger_path '/v0/form21p530a/download_pdf' do
        operation :get do
          key :description, 'Download a pre-filled 21P-530a PDF form'
          key :operationId, 'downloadForm21p530aPdf'
          key :tags, %w[benefits_forms]
          key :produces, ['application/pdf']

          parameter do
            key :name, :form
            key :in, :query
            key :description, 'Form data for PDF generation (JSON string)'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'PDF file download'
          end
        end
      end
    end
  end
end
