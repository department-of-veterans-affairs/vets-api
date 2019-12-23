# frozen_string_literal: true

module Swagger
  module Schemas
    class Appeals
      swagger_schema :HigherLevelReviewRequest, type: :object do
        key :required, %i[data]
        property :data, type: :object do
          key :required, %i[
            type
            attributes
            relationships
          ]
          property :type, type: :string, enum: %w[HigherLevelReview]
          property :attributes, type: :object do
            key :required, %i[
              receipt_date
              informal_conference
              same_office
              legacy_opt_in_approved
              benefit_type
              veteran
            ]
            property :receipt_date, type: :string, format: :date
            property :informal_conference, type: :boolean do
              key :description, 'Corresponds to "14. ...REQUEST AN INFORMAL CONFERENCE..." on form 20-0996.'
            end
            property :informal_conference_times, type: :array do
              key :description, '"OPTIONAL. Time slot preference for informal conference (if being requested).'\
                                'EASTERN TIME. Pick up to two time slots (or none if no preference). Corresponds'\
                                ' to "14. ...REQUEST AN INFORMAL CONFERENCE..." on form 20-0996."'
            end
          end
        end
      end
    end
  end
end
