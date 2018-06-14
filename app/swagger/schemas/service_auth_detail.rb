# frozen_string_literal: true

module Swagger
  module Schemas
    class ServiceAuthDetail
      include Swagger::Blocks

      swagger_schema :ServiceAuthDetail do
        key :required, [:data]

        property :data, type: :object do
          property :attributes, type: :object do
            # key :required, %i[policy policy_action is_authorized errors]
            property :policy, type: :string, example: 'evss'
            property :policy_action, type: :string, example: 'access'
            property :is_authorized, type: :boolean, example: false
            property :errors, type: :object
          end
          property :id, type: :string, example: nil
          property :type, type: :string, example: 'evss_letters_letters_response'
        end
      end
    end
  end
end
