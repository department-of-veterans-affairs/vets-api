# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class SubmitDisabilityForm
        include Swagger::Blocks

        swagger_schema :SubmitDisabilityForm do
          key :required, [:data]

          property :data, type: :object do
            property :attributes, type: :object do
              key :required, [:job_id]
              property :job_id, type: :string, example: 'b4a577edbccf1d805744efa9'
            end
          end
        end
      end
    end
  end
end
