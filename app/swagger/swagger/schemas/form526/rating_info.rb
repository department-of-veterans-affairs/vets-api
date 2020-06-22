# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class RatingInfo
        include Swagger::Blocks

        swagger_schema :RatingInfo do
          property :disability_decision_type_name, type: :string, example: 'Service Connected'
          property :service_connected_combined_degree, type: :integer, example: 90
          property :user_percent_of_disability, type: :integer, example: 90
        end
      end
    end
  end
end
