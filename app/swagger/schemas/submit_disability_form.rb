# frozen_string_literal: true

module Swagger
  module Schemas
    class SubmitDisabilityForm
      include Swagger::Blocks

      swagger_schema :SubmitDisabilityForm do
        key :required, [:data]

        property :data, type: :object do
          property :attributes, type: :object do
            key :required, [:job_id]
            property :job_id, type: :string, example: 'gZEaC2dvIOgHLEk9Sw97Og'
          end
        end
      end
    end
  end
end
