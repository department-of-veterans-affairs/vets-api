# frozen_string_literal: true

module VbaDocuments
  class DocumentUploadStatusAttributesSwagger
    include Swagger::Blocks
    swagger_schema :DocumentUploadStatusAttributes do
      key :required, %i[guid status]

      property :guid do
        key :description, 'The document upload identifier'
        key :type, :string
        key :format, :uuid
        key :example, '6d8433c1-cd55-4c24-affd-f592287a7572'
      end

      property :status do
        key :description, File.read(Rails.root.join('modules', 'vba_documents', 'app', 'swagger', 'vba_documents', 'document_upload_status_description.md'))
        key :type, :string
        key :enum, %i[pending uploaded recieved processing success error]
      end

      property :code do
        key :description, File.read(Rails.root.join('modules', 'vba_documents', 'app', 'swagger', 'vba_documents', 'document_upload_status_code_description.md'))
        key :type, :string
      end

      property :message do
        key :description, 'Humar readable error description. Only present if status = "error"'
        key :type, :string
      end

      property :detail do
        key :description, 'Human readable error detail. Only present if status = "error"'
        key :type, :string
      end
    end
  end
end
