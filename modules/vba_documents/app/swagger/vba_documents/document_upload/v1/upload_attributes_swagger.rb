# frozen_string_literal: true

module VBADocuments
  module DocumentUpload
    module V1
      class UploadAttributesSwagger
        include Swagger::Blocks
        swagger_component do
          schema :DocumentUploadAttributes do
            key :required, %i[guid status]
            property :guid do
              key :description, 'The document upload identifier'
              key :type, :string
              key :format, :uuid
              key :example, '6d8433c1-cd55-4c24-affd-f592287a7572'
            end

            property :status do
              key :description, File.read(VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'document_upload', 'v1', 'status_description.md'))
              key :type, :string
              key :enum, %i[pending uploaded received processing success vbms error]
              key :example, 'pending'
            end

            property :code do
              key :description, File.read(VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'document_upload', 'status_code_description.md'))
              key :type, :string
              key :example, nil
            end

            property :detail do
              key :description, 'Human readable error detail. Only present if status = "error"'
              key :type, :string
              key :example, ''
            end

            property :final_status do
              key :description, 'Indicates whether the status of the submission is final. Submissions with a final_status of true will no longer update to a new status.'
              key :type, :boolean
              key :example, false
            end

            property :location do
              key :description, 'Location to which to PUT document Payload'
              key :type, :string
              key :format, :uri
              key :example, 'https://sandbox-api.va.gov/services_user_content/vba_documents/{idpath}'
            end

            property :updated_at do
              key :description, 'The last time the submission was updated'
              key :type, :string
              key :format, 'date-time'
              key :example, '2018-07-30T17:31:15.958Z'
            end

            property :uploaded_pdf do
              key :description, 'Only populated after submission starts processing'
              key :example, 'null'
            end
          end
        end
      end
    end
  end
end
