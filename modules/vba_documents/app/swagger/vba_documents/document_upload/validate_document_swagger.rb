# frozen_string_literal: true

module VBADocuments
  module DocumentUpload
    class ValidateDocumentSwagger
      include Swagger::Blocks
      swagger_component do
        schema :DocumentValidationErrorModel do
          key :type, :object
          key :description, 'Error returned from the document validation endpoint.'
          key :required, %i[title detail status]

          property :title do
            key :type, :string
            key :example, 'Document failed validation'
            key :description, 'Error title'
          end

          property :detail do
            key :type, :string
            key :description, File.read(VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'document_upload', 'validate_document_error_details.md'))
            key :example, 'Document is locked with a user password'
          end

          property :status do
            key :type, :string
            key :example, '422'
            key :description, 'HTTP error code'
          end
        end
      end
    end
  end
end
