# frozen_string_literal: true

module Swagger
  module Requests
    class ClaimDocuments
      include Swagger::Blocks

      swagger_path '/v0/claim_attachments' do
        operation :post do
          extend Swagger::Responses::UnprocessableEntityError
          extend Swagger::Responses::SavedForm

          key :description, 'Submit a claim document'
          key :operationId, 'addClaimDocument'
          key :tags, %w[saved_claims claim_attachments]

          parameter do
            key :name, :form
            key :in, :body
            key :description, 'Claim Document Data'
            key :required, true

            schema do
              key :required, %i[file form_id]
              property :file, type: :object
              property :form_id, type: :string, example: '21P-530EZ'
            end
          end
        end
      end
    end
  end
end
