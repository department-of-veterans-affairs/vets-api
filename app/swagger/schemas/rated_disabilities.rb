# frozen_string_literal: true

module Swagger
  module Schemas
    class RatedDisabilities
      include Swagger::Blocks

      swagger_schema :RatedDisabilities do
        key :required, [:data]

        property :data, type: :object do
          property :attributes, type: :object do
            key :required, [:rated_disabilities]
            property :rated_disabilities do
              items do
                key :type, :array
                key :'$ref', :RatedDisability
              end
            end
          end
          property :id, type: :string, example: nil
          property :type, type: :string, example: 'evss_disability_compensation_form_rated_disabilities_response'
        end
      end

      swagger_schema :RatedDisability do
        key :required,
            %i[decision_code
               decision_text
               name
               effective_date
               rated_disability_id
               rating_decision_id
               rating_percentage
               related_disability_date
               special_issues]
        property :decision_code, type: :string, example: 'SVCCONNCTED'
        property :decision_text, type: :string, example: 'Service Connected'
        property :name, type: :string, example: 'Diabetes mellitus0'
        property :effective_date, type: :datetime, example: '2018-03-27T21:00:41.000+0000'
        property :rated_disability_id, type: :string, example: '0'
        property :rating_decision_id, type: :string, example: '63655'
        property :rating_percentage, type: :integer, example: '100'
        property :related_disability_date, type: :datetime, example: '2018-03-27T21:00:41.000+0000'
        property :special_issues do
          items do
            key :type, :array
            key :'$ref', :SpecialIssue
          end
        end
      end

      swagger_schema :SpecialIssue do
        key :required, %i[code name]
        property :code, type: :string, example: 'TRM'
        property :name, type: :string, example: 'Personal Trauma PTSD'
      end
    end
  end
end
