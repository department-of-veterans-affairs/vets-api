# frozen_string_literal: true

module VBADocuments
  module V1
    class ControllerSwagger
      include Swagger::Blocks
      VBA_TAG = ['VBA Documents'].freeze
      swagger_path '/uploads' do
        operation :post, tags: VBA_TAG do
          extend VBADocuments::Responses::ForbiddenError
          extend VBADocuments::Responses::TooManyRequestsError
          extend VBADocuments::Responses::InternalServerError
          extend VBADocuments::Responses::UnexpectedError
          extend VBADocuments::Responses::UnauthorizedError
          key :summary, 'Get a location for subsequent document upload PUT request'
          key :operationId, 'postBenefitsDocumentUpload'
          security do
            key :apikey, []
          end
          key :tags, [
            VBA_TAG
          ]

          response 202 do
            key :description, 'Accepted. Location generated'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, %i[data]
                property :data do
                  key :$ref, :DocumentUploadPath
                end
              end
            end
          end
        end
      end

      swagger_path '/path' do
        operation :put, tags: VBA_TAG do
          extend VBADocuments::Responses::InternalServerError
          extend VBADocuments::Responses::UnauthorizedError
          extend VBADocuments::Responses::TooManyRequestsError
          extend VBADocuments::Responses::UnexpectedError
          key :summary, 'Accepts document upload.'
          key :description, File.read(VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'document_upload', 'put_description.md'))
          key :operationId, 'putBenefitsDocumentUpload'

          key :tags, [
            VBA_TAG
          ]

          parameter do
            key :name, 'Content-MD5'
            key :in, 'header'
            key :description, 'Base64-encoded 128-bit MD5 digest of the message. Use for integrity control'
            key :required, false
            schema do
              key :type, :string
              key :format, :md5
            end
          end

          response 200 do
            key :description, 'Document upload staged'
          end

          response 403 do
            key :description, 'Document upload failed'
            content 'application/xml' do
              schema do
                key :$ref, :DocumentUploadFailure
              end
            end
          end
        end
      end

      swagger_path '/uploads/{id}' do
        operation :get, tags: VBA_TAG do
          extend VBADocuments::Responses::NotFoundError
          extend VBADocuments::Responses::TooManyRequestsError
          extend VBADocuments::Responses::InternalServerError
          extend VBADocuments::Responses::UnauthorizedError
          extend VBADocuments::Responses::ForbiddenError
          key :summary, 'Get status for a previous benefits document upload'
          key :operationId, 'getBenefitsDocumentUploadStatus'
          key :description, 'A request to the `/uploads/{id}` endpoint will return a real-time status for that GUID, ' \
                            'and update its status in `/uploads/report`.\n\n' \
                            'The `updated_at` field indicates the last time the status for a given GUID was updated.'

          key :tags, [
            VBA_TAG
          ]

          security do
            key :apikey, []
          end

          parameter do
            key :name, 'id'
            key :in, :path
            key :description, 'ID as returned by a previous create upload request'
            key :required, true
            key :example, '6d8433c1-cd55-4c24-affd-f592287a7572'
            schema do
              key :type, :string
              key :format, :uuid
            end
          end

          response 200 do
            key :description, 'Upload status retrieved successfully'
            content 'application/json' do
              schema do
                key :required, %i[data]
                property :data do
                  key :$ref, :DocumentUploadStatus
                end
              end
            end
          end
        end
      end

      swagger_path '/uploads/{id}/download' do
        operation :get, tags: VBA_TAG do
          extend VBADocuments::Responses::UnauthorizedError
          extend VBADocuments::Responses::TooManyRequestsError
          extend VBADocuments::Responses::ForbiddenError
          extend VBADocuments::Responses::NotFoundError
          extend VBADocuments::Responses::InternalServerError
          key :summary, 'Download zip of "what the server sees"'
          key :description, 'An endpoint that will allow you to see exactly what the server sees. We split apart all submitted docs and metadata and zip the file to make it available to you to help with debugging purposes. Files are deleted after 10 days. Only available in testing environments, not production.'
          key :operationId, 'getBenefitsDocumentUploadDownload'

          key :tags, [VBA_TAG]

          security do
            key :apikey, []
          end

          parameter do
            key :name, 'id'
            key :in, :path
            key :description, 'ID as returned by a previous create upload request'
            key :required, true
            key :example, '6d8433c1-cd55-4c24-affd-f592287a7572'
            schema do
              key :type, :string
              key :format, :uuid
            end
          end

          response 200 do
            key :description, 'Zip file with the contents of your payload as parsed by our server'
            content 'application/zip' do
              schema do
                key :type, :string
                key :format, :binary
                key :example, 'Binary File'
              end
            end
          end
        end
      end

      swagger_path '/uploads/report' do
        operation :post, tags: VBA_TAG do
          extend VBADocuments::Responses::UnauthorizedError
          extend VBADocuments::Responses::TooManyRequestsError
          extend VBADocuments::Responses::ForbiddenError
          extend VBADocuments::Responses::UnexpectedError
          extend VBADocuments::Responses::InternalServerError
          key :tags, [VBA_TAG]

          key :summary, 'Get a bulk status report for a list of previous uploads'
          key :operationId, 'getBenefitsDocumentUploadStatusReport'
          key :description, 'Due to current system limitations, data for the `/uploads/report` endpoint is cached for one hour.' \
                            '\n\n' \
                            'A request to the `/uploads/{id}` endpoint will return a real-time status for that GUID, ' \
                            'and update its status in `/uploads/report`.' \
                            '\n\n' \
                            'The `updated_at` field indicates the last time the status for a given GUID was updated.'

          security do
            key :apikey, []
          end

          request_body do
            key :description, 'List of GUIDs for which to retrieve current status'
            key :required, true

            content 'application/json' do
              schema do
                key :$ref, :DocumentUploadStatusGuidList
              end
            end
          end
          response 200 do
            key :description, 'Upload status report retrieved successfully'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, %i[data]

                property :data do
                  key :$ref, :DocumentUploadStatusReport
                end
              end
            end
          end

          response 400 do
            key :description, 'Bad Request - invalid or missing list of guids'
          end
        end
      end

      swagger_path '/uploads/validate_document' do
        operation :post, tags: VBA_TAG do
          extend VBADocuments::Responses::UnauthorizedError
          extend VBADocuments::Responses::TooManyRequestsError
          extend VBADocuments::Responses::ForbiddenError
          extend VBADocuments::Responses::UnexpectedError
          extend VBADocuments::Responses::InternalServerError
          key :tags, [
            VBA_TAG
          ]

          key :summary, 'Validate an individual document against system file requirements'
          key :description, File.read(VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'document_upload', 'validate_document_description.md'))
          key :operationId, 'postBenefitsDocumentUploadValidateDocument'

          response 200 do
            key :description, 'Document passed system requirements'
            content 'application/json' do
              schema do
                key :type, :object
                property :data do
                  property :type do
                    key :type, :string
                    key :example, 'documentValidation'
                    key :description, 'schema type'
                  end

                  property :attributes do
                    key :type, :object

                    property :status do
                      key :type, :string
                      key :example, 'valid'
                    end
                  end
                end
              end
            end
          end

          response 422 do
            key :description, 'Document did NOT pass system requirements'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]

                property :errors do
                  key :type, :array
                  items do
                    key :$ref, :DocumentValidationErrorModel
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
