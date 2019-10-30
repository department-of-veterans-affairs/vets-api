# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class RatingInfo
        include Swagger::Blocks

        swagger_schema :RatingInfo do
          key :required,
              %i[effective_date
                 rating_record
                 some_text]
          property :effective_date, type: :string, example: '2018-03-27T21:00:41.000+0000'
          property :rating_record, type: :integer, example: '40'
          property :some_text, type: :string, example: 'Dummy Data'
          property :user_percent_of_disability, type: :integer, example: '90'
        end
      end
    end
  end
end
