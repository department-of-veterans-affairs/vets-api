# frozen_string_literal: true

module Swagger
  module Schemas
    class SubmissionStatus
      include Swagger::Blocks

      swagger_schema :SubmissionStatus do
        key :required, [:data]

        property :data, type: :object do
          property :attributes, type: :object do
            property :transaction_id, type: :string
            property :transaction_status, type: :string
          end
          property :id, type: :string
          property :type, type: :string
        end
      end
    end
  end
end
