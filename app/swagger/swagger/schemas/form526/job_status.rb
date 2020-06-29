# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class JobStatus
        include Swagger::Blocks

        swagger_schema :JobStatus do
          key :required, [:data]

          property :data, type: :object do
            property :attributes, type: :object do
              property :claim_id, type: :integer
              property :job_id, type: :string
              property :submission_id, type: :integer
              property :status, type: :string
              property :ancillary_item_statuses, type: :array
            end
            property :id, type: :string
            property :type, type: :string
          end
        end
      end
    end
  end
end
