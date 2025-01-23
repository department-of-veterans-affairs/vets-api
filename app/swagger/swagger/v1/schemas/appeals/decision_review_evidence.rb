# frozen_string_literal: true

module Swagger
  module V1
    module Schemas
      module Appeals
        class DecisionReviewEvidence
          include Swagger::Blocks

          swagger_schema :DecisionReviewEvidence do
            property :data, type: :object do
              property :attributes, type: :object do
                key :required, %i[guid]
                property :guid, type: :string, example: '3c05b2f0-0715-4298-965d-f733465ed80a'
              end
              property :id, type: :string, example: '11'
              property :type, type: :string, example: 'decision_review_evidence_attachment'
            end
          end
        end
      end
    end
  end
end
