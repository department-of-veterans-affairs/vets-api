# frozen_string_literal: true

module Swagger
  module Requests
    class Efolder
      include Swagger::Blocks

      swagger_path '/v0/efolder' do
        operation :get do
          key :summary, 'Provides a list of document ids and descriptions from eFolder'
          key :description,
              'Provides a list of document ids and descriptions from eFolder. The documents provided are extracted ' \
              'from VBMS and compared against a list of documents for the user that is provided by BGS. A merge ' \
              'function between the two lists is performed to determine which documents should be viewable for the ' \
              'veteran.'
          key :operationId, 'getDocuments'
          key :tags, %w[efolder]

          response 200 do
            key :description, 'Document metadata retrieved successfully'

            schema do
              items do
                property :document_id, type: :string
                property :doc_type, type: :string
                property :type_description, type: :string
                property :received_at, type: :string, format: 'date'
              end
            end
          end
        end
      end

      swagger_path '/v0/efolder/{id}' do
        operation :get do
          key :summary, 'Allows the veteran to download the document'
          key :description,
              'Provides a method to download a PDF copy of the document. The ID passed into the query string of the ' \
              'URL must match the ID that is attached to the document that is provided by VBMS.'
          key :operationId, 'getDocument'
          key :tags, %w[efolder]

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'Document ID of document'
            key :required, true
            key :type, :string
          end

          response 200 do
            key :description, 'Document download'

            schema do
              property :data, type: :string, format: 'binary'
            end
          end
        end
      end
    end
  end
end
