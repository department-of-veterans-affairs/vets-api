# frozen_string_literal: true

module VbaDocuments
  module DocumentUpload
    class StatusAttributesSwagger
      include Swagger::Blocks
      swagger_component do
        schema :DocumentUploadStatusAttributes do
          key :required, %i[guid status]

          property :guid do
            key :description, 'The document upload identifier'
            key :type, :string
            key :format, :uuid
            key :example, '6d8433c1-cd55-4c24-affd-f592287a7572'
          end

          property :status do
            key :description, File.read(VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'document_upload', 'status_description.md'))
            key :type, :string
            key :enum, %i[pending uploaded recieved processing success error]
          end

          property :code do
            key :description, File.read(VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'document_upload', 'status_code_description.md'))
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

          property :updated_at do
            key :description, 'The last time the submission was updated'
            key :type, :string
            key :format, 'date-time'
            key :example, '2018-07-30T17:31:15.958Z'
          end
        end
      end
    end
  end
end
