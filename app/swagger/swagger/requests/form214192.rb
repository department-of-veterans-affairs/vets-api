# frozen_string_literal: true

module Swagger
  module Requests
    class Form214192
      include Swagger::Blocks

      swagger_schema :Form214192Address do
        key :type, :object
        property :street, type: :string, example: '123 Main St'
        property :street2, type: :string, example: 'Apt 4B'
        property :city, type: :string, example: 'Springfield'
        property :state, type: :string, example: 'IL'
        property :postalCode, type: :string, example: '62701'
        property :country, type: :string, example: 'USA'
      end

      swagger_schema :Form214192FullName do
        key :type, :object
        property :first, type: :string, example: 'John'
        property :middle, type: :string, example: 'M'
        property :last, type: :string, example: 'Doe'
      end

      swagger_schema :Form214192ContactInfo do
        key :type, :object
        property :name, type: :string, example: 'Jane Smith'
        property :title, type: :string, example: 'HR Manager'
        property :phone, type: :string, example: '555-987-6544'
        property :email, type: :string, example: 'jane.smith@acme.com'
      end

      swagger_path '/v0/form214192' do
        operation :post do
          extend Swagger::Responses::SavedForm

          key :description,
              'Submit a 21-4192 form (Request for Employment Information in Connection with Claim for ' \
              'Disability Benefits)'
          key :operationId, 'submitForm214192'
          key :tags, %w[benefits_forms]

          parameter do
            key :name, :form214192
            key :in, :body
            key :description, 'Form 21-4192 submission data'
            key :required, true

            schema do
              key :type, :object

              property :veteranInformation do
                key :type, :object
                key :required, %i[fullName dateOfBirth]

                property :fullName do
                  key :$ref, :Form214192FullName
                end
                property :ssn, type: :string, example: '123456789'
                property :vaFileNumber, type: :string, example: '987654321'
                property :dateOfBirth, type: :string, format: :date, example: '1980-01-01'
                property :address do
                  key :$ref, :Form214192Address
                end
                property :phoneNumber, type: :string, example: '555-123-4567'
                property :emailAddress, type: :string, example: 'veteran@example.com'
              end

              property :employmentInformation do
                key :type, :object
                key :required,
                    %i[employerName employerAddress employerEmail typeOfWorkPerformed beginningDateOfEmployment]

                property :employerName, type: :string, example: 'Acme Corporation'
                property :employerAddress do
                  key :$ref, :Form214192Address
                end
                property :employerPhone, type: :string, example: '555-987-6543'
                property :employerEmail, type: :string, example: 'hr@acme.com'
                property :contactPerson do
                  key :$ref, :Form214192ContactInfo
                end
                property :typeOfWorkPerformed, type: :string, example: 'Software Developer'
                property :beginningDateOfEmployment, type: :string, format: :date, example: '2015-01-15'
                property :endingDateOfEmployment, type: :string, format: :date, example: '2023-06-30'
                property :amountEarnedLast12MonthsOfEmployment, type: :number, example: 75_000
                property :timeLostLast12MonthsOfEmployment, type: :string, example: '2 weeks'
                property :hoursWorkedDaily, type: :number, example: 8
                property :hoursWorkedWeekly, type: :number, example: 40
                property :concessions, type: :string, example: 'Flexible hours, ergonomic desk, modified duties'
                property :terminationReason, type: :string, example: 'Medical disability'
                property :dateLastWorked, type: :string, format: :date, example: '2023-06-30'
                property :lastPaymentDate, type: :string, format: :date, example: '2023-07-15'
                property :lastPaymentGrossAmount, type: :number, example: 6250
                property :lumpSumPaymentMade, type: :boolean, example: false
                property :grossAmountPaid, type: :number, example: 0
                property :datePaid, type: :string, format: :date, example: '2023-07-15'
              end

              property :militaryDutyStatus do
                key :type, :object
                key :description, 'Section III - Reserve or National Guard Duty Status'

                property :currentDutyStatus, type: :string, example: 'Active Reserve'
                property :veteranDisabilitiesPreventMilitaryDuties, type: :boolean, example: true
              end

              property :benefitEntitlementPayments do
                key :type, :object
                key :description, 'Section IV - Information on Benefit Entitlement and/or Payments'

                property :sickRetirementOtherBenefits, type: :boolean, example: false
                property :typeOfBenefit, type: :string, example: 'Retirement'
                property :grossMonthlyAmountOfBenefit, type: :number, example: 1500
                property :dateBenefitBegan, type: :string, format: :date, example: '2023-01-01'
                property :dateFirstPaymentIssued, type: :string, format: :date, example: '2023-02-01'
                property :dateBenefitWillStop, type: :string, format: :date, example: '2025-12-31'
                property :remarks, type: :string, example: 'Additional information about benefits and payments'
              end
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

      swagger_path '/v0/form214192/download_pdf' do
        operation :post do
          key :description, 'Download a pre-filled 21-4192 PDF form'
          key :operationId, 'downloadForm214192Pdf'
          key :tags, %w[benefits_forms]
          key :produces, ['application/pdf']

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
          end
        end
      end
    end
  end
end
