# frozen_string_literal: true
# require 'evss_claim_document'

module Swagger
  module Requests
    class EVSSClaimUploads
      include Swagger::Blocks

      swagger_path '/v0/evss_claims/documents/upload' do
        operation :post do
          extend Swagger::Responses::AuthenticationError

          key :description, 'Uploads a document to later be submitted with a 526 claim for increase'
          key :operationId, 'postEvssClaimDocument'

          parameter :authorization

          parameter do
            key :name, 'file'
            key :in, :body
            key :description, 'The file to upload'
            key :required, true
            schema do
              # w/o this, it spits this error out:
              # "The document fails to validate as Swagger 2.0"
            end
          end

          parameter do
            key :name, 'document_type'
            key :in, :path # TODO: make this :body w/o "The document fails to validate as Swagger 2.0"
            key :description, 'The type of document being uploaded'
            key :required, true
            key :type, :string
            key :enum, EVSSClaimDocument::DOCUMENT_TYPES.map { |k, _v| k }
          end

          response 201 do
            key :description, 'Created'
          end
        end
      end
    end
  end
end