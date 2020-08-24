# frozen_string_literal: true

module Swagger
  class Efolder
    include Swagger::Blocks

    swagger_path '/v0/efolder' do
      operation :get do
        key :description, 'Provides an array of document ids and descriptions from eFolder'
        key :operationId, 'getDocuments'
        key :tags, %w[efolder]

        parameter do
          key :name, :included_doc_types
          key :in, :body
          key :description, 'List of doc_types to include in the response'
          key :required, false
          key :type, :array
        end

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
        key :description, 'Allows the veteran to download the document'
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
