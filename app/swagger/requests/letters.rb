# frozen_string_literal: true
module Swagger
  module Requests
    class Letters
      include Swagger::Blocks

      swagger_path '/v0/letters' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Get a list of available letters for a veteran'
          key :operationId, 'getLetters'
          key :tags, %w(
            evss
          )

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Letters
            end
          end
          response 404 do
            key :description, 'User or letters not found in EVSS'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end

      swagger_path '/v0/letters/beneficiary' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Returns a list of benefit options for use with POST /v0/letters'
          key :operationId, 'getLettersBeneficiary'
          key :tags, %w(
            evss
          )

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :LetterBeneficiary
            end
          end
          response 404 do
            key :description, 'User not found in EVSS'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end

      swagger_path '/v0/letters' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Returns a letter as a PDF'
          key :operationId, 'postLetter'
          key :tags, %w(
            evss
          )

          parameter :authorization
          parameter do
            key :in, :body
            key :description, 'Health care application form data'
            key :required, false

            schema do
              property :hasNonServiceConnectedPension, type: :boolean, example: true
              property :hasServiceConnectedDisabilities, type: :boolean, example: true
              property :hasSurvivorsIndemnityCompensationAward, type: :boolean, example: true
              property :hasSurvivorsPensionAward, type: :boolean, example: true
              property :monthlyAwardAmount, type: :number, example: true
              property :serviceConnectedPercentage, type: :integer, example: true
              property :awardEffectiveDate, type: :string, example: true
              property :hasAdaptedHousing, type: [:boolean, :null], example: true
              property :hasChapter35Eligibility, type: [:boolean, :null], example: true
              property :hasDeathResultOfDisability, type: [:boolean, :null], example: true
              property :hasIndividualUnemployabilityGranted, type: [:boolean, :null], example: true
              property :hasSpecialMonthlyCompensation, type: [:boolean, :null], example: true
            end
          end

          response 200 do
            key :description, 'Response is OK'
          end
          response 404 do
            key :description, 'User not found in EVSS'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end

      swagger_schema :Letters do
        key :required, [:data, :meta]

        property :data, type: :object do
          property :attributes, type: :object do
            property :letters do
              key :type, :array
              items do
                key :'$ref', :Letter
              end
            end
          end
          property :id, type: :string, example: nil
          property :type, type: :string, example: 'evss_letters_letters_response'
        end

        property :meta, type: :object do
          property :address, type: :object do
            key :required, [:full_name, :address_line1, :address_line2, :address_line3, :city, :state, :country, :foreign_code, :zip_code]
            property :full_name, type: :string, example: 'Abraham Lincoln'
            property :address_line1, type: :string, example: '140 Rock Creek Church Rd NW'
            property :address_line2, type: :string, example: nil
            property :address_line3, type: :string, example: nil
            property :city, type: :string, example: 'Washington'
            property :state, type: :string, example: 'DC'
            property :country, type: :string, example: 'USA'
            property :foreign_code, type: :string, example: nil
            property :zip_code, type: :string, example: '20011'
          end
          property :status, type: :string, enum: %w(OK NOT_AUTHORIZED NOT_FOUND SERVER_ERROR), example: 'OK'
        end
      end

      swagger_schema :Letter do
        key :required, [:name, :letter_type]
        property :name, type: :string, example: 'Proof of Service Letter'
        property :letter_type, type: :string, enum: %w(
            commissary
            proof_of_service
            medicare_partd
            minimum_essential_coverage
            service_verification
            civil_service
            benefit_summary
            benefit_verification
            certificate_of_eligibility
          ),
          example: 'proof_of_service'
      end

      swagger_schema :LetterBeneficiary do
        key :required, [:meta, :data]
        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            key :required, [:benefit_information, :military_service]
            property :benefit_information, type: :object do
              property :has_non_service_connected_pension, type: :boolean, example: true
              property :has_service_connected_disabilities, type: :boolean, example: true
              property :has_survivors_indemnity_compensation_award, type: :boolean, example: true
              property :has_survivors_pension_award, type: :boolean, example: true
              property :monthly_award_amount, type: :number, example: true
              property :service_connected_percentage, type: :integer, example: true
              property :award_effective_date, type: :string, example: true
              property :has_adapted_housing, type: [:boolean, :null], example: true
              property :has_chapter35_eligibility, type: [:boolean, :null], example: true
              property :has_death_result_of_disability, type: [:boolean, :null], example: true
              property :has_individual_unemployability_granted, type: [:boolean, :null], example: true
              property :has_special_monthly_compensation, type: [:boolean, :null], example: true
            end
            property :military_service do
              items do
                property :branch, type: :string, example: 'ARMY'
                property :character_of_service, type: :string, example: 'HONORABLE'
                property :entered_date, type: :string, example: '1973-01-01T05:00:00.000+00:00'
                property :released_date, type: :string, example: '1977-10-01T04:00:00.000+00:00'
              end
            end
          end
          property :id, type: :string, example: nil
          property :type, type: :string, example: 'evss_letters_letter_beneficiary_response'
        end
        property :meta, type: :object do
          property :status, type: :string, enum: %w(OK NOT_AUTHORIZED NOT_FOUND SERVER_ERROR), example: 'OK'
        end
      end
    end
  end
end
