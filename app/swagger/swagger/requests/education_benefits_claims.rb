# frozen_string_literal: true

module Swagger
  module Requests
    class EducationBenefitsClaims
      include Swagger::Blocks

      swagger_path '/v0/education_benefits_claims/{form_type}' do
        operation :post do
          extend Swagger::Responses::ValidationError

          key :description, 'Submit an education benefits claim'
          key :operationId, 'addEducationBenefitsClaim'
          key :tags, %w[benefits_forms]

          parameter do
            key :name, :education_benefits_claim
            key :in, :body
            key :description, 'Education benefits form data'
            key :required, true
            schema do
              key :$ref, :EducationBenefitsClaimInput
            end
          end

          parameter do
            key :name, :form_type
            key :in, :path
            key :description, 'Form code. Allowed values: 1990 1995 5490'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'create education benefits claim response'
            schema do
              key :$ref, :EducationBenefitsClaimData
            end
          end
        end
      end

      swagger_schema :EducationBenefitsClaimInput do
        key :required, [:form]

        property :form do
          key :type, :string
          key :description, 'Should conform to vets-json-schema (https://github.com/department-of-veterans-affairs/vets-json-schema)'
        end
      end

      swagger_schema :EducationBenefitsClaimData do
        key :required, [:data]

        property :data, type: :object do
          property :id, type: :string
          property :type, type: :string

          property :attributes, type: :object do
            property :form, type: :string
            property :submitted_at, type: :string
            property :regional_office, type: :string
            property :confirmation_number, type: :string
          end
        end
      end

      swagger_path '/v0/education_benefits_claims/stem_claim_status' do
        operation :get do
          key :description, 'Get a list of user STEM benefit claims'
          key :operationId, 'getStemClaimStatus'
          key :tags, %w[
            benefits_info
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :$ref, :EducationStemClaimStatusData
            end
          end
        end
      end

      swagger_schema :EducationStemClaimStatusData do
        key :required, [:data]

        property :data, type: :array, minItems: 0, uniqueItems: true do
          property :id, type: :string
          property :type, type: :string

          property :attributes, type: :object do
            property :is_enrolled_stem,
                     type: :boolean,
                     example: true,
                     description: 'Submitted 10203 `is_enrolled_stem` form value'
            property :is_pursuing_teaching_cert,
                     type: :boolean,
                     example: true,
                     description: 'Submitted 10203 `is_pursuing_teaching_cert` form value'
            property :benefit_left,
                     type: :string,
                     example: 'none',
                     description: 'Submitted 10203 `benefit_left` form value'
            property :remaining_entitlement,
                     type: :integer,
                     example: 127,
                     description: 'EVSS remaining entitlement in days'
            property :automated_denial,
                     type: :boolean,
                     example: false,
                     description: 'Submitted 10203 `benefit_left` form value'
            property :denied_at,
                     type: :string,
                     example: '2021-02-12T19:23:49.443Z',
                     description: 'STEM automated denial date time'
            property :submitted_at,
                     type: :string,
                     example: '2021-02-12T19:15:22.178Z',
                     description: 'Form submission date time'
          end
        end
      end
    end
  end
end
