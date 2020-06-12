# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class Disability
        include Swagger::Blocks

        swagger_schema :NewDisability do
          key :required, %i[condition cause]

          property :condition, type: :string
          property :cause, type: :string, enum:
            %w[
              NEW
              SECONDARY
              WORSENED
              VA
            ]
          property :classificationCode, type: :string
          property :primaryDescription, type: :string
          property :causedByDisability, type: :string
          property :causedByDisabilityDescription, type: :string
          property :specialIssues, type: :array do
            items do
              key :'$ref', :SpecialIssue
            end
          end
          property :worsenedDescription, type: :string
          property :worsenedEffects, type: :string
          property :vaMistreatmentDescription, type: :string
          property :vaMistreatmentLocation, type: :string
          property :vaMistreatmentDate, type: :string
        end

        swagger_schema :RatedDisability do
          key :required, %i[name disabilityActionType]

          property :name, type: :string
          property :disabilityActionType, type: :string, enum:
            %w[
              NONE
              NEW
              SECONDARY
              WORSENED
              VA
            ]
          property :specialIssues, type: :array do
            items do
              key :'$ref', :SpecialIssue
            end
          end
          property :ratedDisabilityId, type: :string
          property :ratingDecisionId, type: :string
          property :diagnosticCode, type: :number
          property :classificationCode, type: :string
          property :secondaryDisabilities, type: :array, maxItems: 100 do
            items type: :object do
              key :required, %i[name disabilityActionType]

              property :name, type: :string
              property :disabilityActionType, type: :string, enum:
                %w[
                  NONE
                  NEW
                  SECONDARY
                  WORSENED
                  VA
                ]
              property :specialIssues, type: :array do
                items do
                  key :'$ref', :SpecialIssue
                end
              end
              property :ratedDisabilityId, type: :string
              property :ratingDecisionId, type: :string
              property :diagnosticCode, type: :number
              property :classificationCode, type: :string
            end
          end
        end

        swagger_schema :SpecialIssue do
          property :items, type: :string, enum:
            %w[
              ALS
              HEPC
              POW
              PTSD/1
              PTSD/2
              PTSD/3
              PTSD/4
              MST
            ]
        end
      end
    end
  end
end
