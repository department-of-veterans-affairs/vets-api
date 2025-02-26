# frozen_string_literal: true

module VBADocuments
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
            key :enum, %i[pending uploaded received processing success error]
            key :example, 'error'
          end

          property :code do
            key :description, File.read(VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'document_upload', 'status_code_description.md'))
            key :type, :string
            key :example, 'DOC108'
          end

          property :detail do
            key :description, 'Human readable error detail. Only present if status = "error"'
            key :type, :string
            key :example, 'Maximum page size exceeded. Limit is 78 in x 101 in.'
          end

          property :final_status do
            key :description, 'Indicates whether the status of the submission is final. Submissions with a final_status of true will no longer update to a new status.'
            key :type, :boolean
            key :example, true
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
