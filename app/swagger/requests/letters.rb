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
        end
      end

      swagger_path '/v0/letters/beneficiary' do
        operation :get do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Returns service history, and a list of benefit options for use with POST /v0/letters'
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
        end
      end

      swagger_path '/v0/letters/{id}' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Returns a letter as a PDF blob'
          key :operationId, 'postLetter'
          key :tags, %w(
            evss
          )

          parameter :authorization
          parameter do
            key :name, :body
            key :in, :body
            key :description, 'Options to include in generated PDF'
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
        end
      end
    end
  end
end
