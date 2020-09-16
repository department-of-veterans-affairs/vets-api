# frozen_string_literal: true

module Swagger
  module Schemas
    module Appeals
      class IntakeStatus
        include Swagger::Blocks

        swagger_schema :IntakeStatus do
          key :type, :object
          key :description, 'An accepted Decision Review still needs to be processed '\
                            'before the Decision Review can be accessed'
          property :data, type: :object do
            property :id, type: :string
            property :type, type: :string, description: 'Will be Intake Status'
            property :attributes, type: :object do
              property :status, type: :string do
                key :enum, %w[
                  processed
                  canceled
                  attempted
                  submitted
                  not_yet_submitted
                ]
                key :description, '`not_yet_submitted` - The DecisionReview has not been submitted yet.
                                  `submitted` - The DecisionReview is in the queue to be attempted.
                                  `attempted` - Processing of the DecisionReview is being attempted.
                                  `canceled` - The DecisionReview has been successfully canceled.
                                  `processed` - The DecisionReview has been processed and transmitted '\
                                  'to the appropriate government agency.'
              end
            end
          end
        end
      end
    end
  end
end
