# frozen_string_literal: true

module Swagger
  module Schemas
    class Appeals
      include Swagger::Blocks

      swagger_schema :Appeals do
        key :required, [:data]
        property :data, type: :array
      end

      swagger_schema :HigherLevelReview do
        key :required, [:data, :included]
        property :data, type: :object do
          property :id do
            key :type, :string
            key :format, :uuid
            key :pattern, '^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$'
          end
          property :type do
            key :type, :string
            key :enum, ['HigherLevelReview']
            key :description, 'Will be "Higher Level Review"'
          end
          property :attributes, type: :object do
            property :status, type: :string
            property :aoj, type: :string, nullable: true
            property :program_area, type: :string
            property :benefit_type do
              key :type, :string
              key :enum, %w[
                compensation
                pension
                fiduciary
                insurance
                education
                voc_rehab
                loan_guaranty
                vha
                nca
              ]
            end
            property :description, type: :string
            property :receipt_date do
              key :type, :string
              key :format, :date
              key :nullable, true
            end
            property :informal_conference, type: :boolean, nullable: true
            property :same_office, type: :boolean, nullable: true
            property :legacy_opt_in_approved, type: :boolean, nullable: true
            property :alerts do
              key :'$ref', :HigherLevelReviewAlerts
            end
          end
          property :relationships do
            key :'$ref', :HigherLevelReviewRelationships
          end
        end
      end

      swagger_schema :HigherLevelReviewAlerts do
        key :type, :array
        items do
          key :type, :object
          property :type, type: :string, enum: ['AmaPostDecision']
          property :details do
            key :type, :object
            property :decision_date, type: :string, nullable: true
            property :available_options do
              key :type, :array
              items do
                key :type, :string
              end
            end
            property :due_date do
              key :type, :string
              key :format, :date
              key :nullable, true
            end
          end
        end
      end

      swagger_schema :HigherLevelReviewRelationships do
        
      end
    end
  end
end
