# frozen_string_literal: true

module VbaDocuments
  module DocumentUpload
    class StatusSwagger
      include Swagger::Blocks
      swagger_component do
        schema :DocumentUploadStatus do
          key :description, 'Status record for a previously initiated document submission.'
          key :required, %i[id type attributes]

          property :id do
            key :description, 'JSON API identifier'
            key :type, :string
            key :format, :uuid
            key :example, '6d8433c1-cd55-4c24-affd-f592287a7572'
          end

          property :type do
            key :description, 'JSON API type specification'
            key :type, :string
            key :example, 'document_upload'
          end

          property :attributes do
            key :$ref, :DocumentUploadStatusAttributes
          end
        end
      end
    end
  end
end
