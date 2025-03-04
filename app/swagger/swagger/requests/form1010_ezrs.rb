# frozen_string_literal: true

module Swagger
  module Requests
    class Form1010Ezrs
      include Swagger::Blocks

      swagger_path '/v0/form1010_ezrs' do
        operation :post do
          extend Swagger::Responses::AuthenticationError
          extend Swagger::Responses::ValidationError
          extend Swagger::Responses::BackendServiceError
          extend Swagger::Responses::InternalServerError

          key :description, 'Submit a 10-10EZR form'
          key :operationId, 'postForm1010Ezr'
          key :tags, %w[benefits_forms]

          parameter :authorization

          parameter do
            key :name, :form
            key :in, :body
            key :description, '10-10EZR form data'
            key :required, true

            schema do
              key :type, :string
            end
          end

          response 200 do
            key :description, 'submit 10-10EZR form response'
            schema do
              key :$ref, :Form1010EzrSubmissionResponse
            end
          end
        end
      end

      swagger_path '/v0/form1010_ezrs/veteran_prefill_data' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Retrieve Veteran enrollment eligibility data from the Enrollment System'
          key :operationId, 'getVeteranPrefillData'
          key :tags, %w[benefits_forms]

          parameter :authorization

          response 200 do
            key :description, 'Veteran enrollment eligibility data retrieved successfully'
            schema do
              key :$ref, :Form1010EzrVeteranPrefillDataResponse
            end
          end
        end
      end

      swagger_schema :Form1010EzrSubmissionResponse do
        key :required, %i[formSubmissionId timestamp success]

        property :formSubmissionId, type: %i[integer null], example: nil
        property :timestamp, type: %i[string null], example: nil
        property :success, type: :boolean
      end

      swagger_schema :Form1010EzrVeteranPrefillDataResponse do
        key :required, [:data]
        property :data, type: :object do
          property :veteranIncome, type: :object do
            property :otherIncome, type: :string
            property :grossIncome, type: :string
            property :netIncome, type: :string
          end
          property :spouseIncome, type: :object do
            property :otherIncome, type: :string
            property :grossIncome, type: :string
            property :netIncome, type: :string
          end
          property :providers, type: :array do
            items do
              property :insuranceName, type: :string
              property :insurancePolicyHolderName, type: :string
              property :insurancePolicyNumber, type: :string
            end
          end
          property :dependents, type: :array do
            items do
              property :fullName, type: :object do
                property :first, type: :string
                property :middle, type: :string
                property :last, type: :string
                property :suffix, type: :string, example: 'Jr.'
              end
              property :socialSecurityNumber, type: :string, example: '111111111'
              property :becameDependent, type: :string, example: '1991-05-06'
              property :dependentRelation, type: :string, example: 'Son'
              property :disabledBefore18, type: :boolean, example: false
              property :attendedSchoolLastYear, type: :boolean, example: true
              property :cohabitedLastYear, type: :boolean, example: true
              property :dateOfBirth, type: :string, example: '1991-05-06'
            end
          end
          property :spouseFullName, type: :object do
            property :first, type: :string
            property :middle, type: :string
            property :last, type: :string
            property :suffix, type: :string, example: 'Sr.'
          end
          property :dateOfMarriage, type: :string, example: '1989-09-16'
          property :cohabitedLastYear, type: :boolean, example: true
          property :spouseDateOfBirth, type: :string, example: '1970-02-21'
          property :spouseSocialSecurityNumber, type: :string, example: '222222222'
          property :spouseIncomeYear, type: :string, example: '2024'
        end
      end
    end
  end
end
