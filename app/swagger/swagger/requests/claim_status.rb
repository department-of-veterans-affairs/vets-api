# frozen_string_literal: true

module Swagger
  module Requests
    class ClaimStatus
      include Swagger::Blocks

      swagger_path '/v0/evss_claims/{evss_claim_id}/documents' do
        operation :post do
          extend Swagger::Responses::UnprocessableEntityError
          key :description, 'upload a document associated with a claim'
          key :operationId, 'postDocument'
          key :tags, %w[claim_status_tool]

          parameter :authorization

          parameter do
            key :name, :cst_file_upload
            key :in, :body
            key :description, ''
            key :required, true
            schema do
              key :'$ref', :ClaimDocumentInput
            end
          end

          parameter do
            key :name, :evss_claim_id
            key :description, ''
            key :in, :path
            key :required, true
            key :type, :string
          end

          response 202 do
            key :description, 'Response is Accepted'
            schema do
              key :required, %i[job_id]
              property :job_id, type: :string, example: ''
            end
          end
        end
      end

      swagger_schema :ClaimDocumentInput do
        key :required, %i[file document_type]

        property :file do
          key :type, :string
        end
        property :tracked_item_id do
          key :type, :string
        end
        property :password do
          key :type, :string
          key :example, 'My Password!'
        end
        property :document_type do
          key :type, :string
          key :example, 'L023'
          key :enum, EVSSClaimDocument::DOCUMENT_TYPES.keys
        end
      end
    end
  end
end
