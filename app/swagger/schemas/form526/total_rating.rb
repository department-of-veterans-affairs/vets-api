# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class TotalRating
        include Swagger::Blocks

        swagger_schema :TotalRating3 do
          key :required, [:data]

          property :data, type: :object do
            property :attributes, type: :object do
              key :required, [:rated_disabilities]
              property :rated_disabilities do
                items do
                  key :type, :object
                  key :'$ref', :RatedDisability
                end
              end
            end
            property :id, type: :string, example: nil
            property :type, type: :string, example: 'evss_disability_compensation_form_total_rating_response'
          end
        end

        swagger_schema :TotalRating do
          key :required,
              %i[effective_date
                 rating_record
                 some_text]
          property :effective_date, type: :string, example: '2018-03-27T21:00:41.000+0000'
          property :rating_record, type: :integer, example: '40'
          property :some_text, type: :string, example: 'Dummy Data'
        end


      end
    end
  end
end
