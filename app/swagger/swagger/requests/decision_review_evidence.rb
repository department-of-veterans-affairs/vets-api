# frozen_string_literal: true

module Swagger
  module Requests
    class DecisionReviewEvidence
      include Swagger::Blocks

      swagger_path '/v0/decision_review_evidence' do
        operation :post do
          extend Swagger::Responses::BadRequestError

          key :description, 'Uploadfile containing supporting evidence for Notice of Disagreement'
          key :operationId, 'decisionReviewEvidence'
          key :tags, %w[nod]

          parameter do
            key :name, :decision_review_evidence_attachment
            key :in, :body
            key :description, 'Object containing file name'
            key :required, true

            schema do
              key :required, %i[file_data]
              property :file_data, type: :string, example: 'filename.pdf'
            end
          end

          response 200 do
            key :description, 'Response is ok'
            schema do
              key :$ref, :DecisionReviewEvidence
            end
          end
        end
      end
    end
  end
end
