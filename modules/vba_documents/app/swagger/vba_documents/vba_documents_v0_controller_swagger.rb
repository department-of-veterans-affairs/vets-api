# frozen_string_literal: true

module VbaDocuments
  class VbaDocumentsV0ControllerSwagger
    include Swagger::Blocks

    swagger_path '/uploads' do
      operation :post do
        key :summary, 'Get a location for subsequent document upload PUT request'
        key :operationId, 'postBenefitsDocumentUpload'
        security do
          key :api_key, []
        end
        key :tags, [
          'document_uploads'
        ]

        response 202 do
          key :description, 'Accepted. Location generated'
          schema do
            key :type, :object
            key :required, [:data]
            property :data do
              key :'$ref', :DocumentUploadSubmission
            end
          end
        end

        response 401 do
          key :description, 'Unauthorized Request'
        end

        response 403 do
          key :description, 'Bad API Token'
        end
      end
    end

    swagger_path '/path' do
      operation :put do
        key :summary, 'Accepts document upload.'
        key :description, File.read(Rails.root.join('modules', 'vba_documents', 'app', 'swagger', 'vba_documents', 'document_upload_put_description.md'))

        key :tags, [
          'document_uploads'
        ]
        parameter do
          key :name, 'Content-MD5'
          key :in, 'header'
          key :description, 'Base64-encoded 128-bit MD5 digest of the message. Use for integrity control.'
          key :required, false
          schema do
            key :type, :string
            key :format, :md5
          end
        end

        key :consumes, ['multipart/form-data']

        parameter do
          key :$ref, :DocumentUploadMetadata
        end

        parameter do
          key :name, 'document'
          key :in, :formData
          key :type, :file
          key :description, 'Document Contents. Must be provided in PDF format'
        end

        parameter do
          key :name, 'attachment1'
          key :in, :formData
          key :type, :file
        end

        parameter do
          key :name, 'attachment2'
          key :in, :formData
          key :type, :file
        end

        response 200 do
          key :description, 'Document upload staged'
        end

        response 400 do
          key :$ref, :DocumentUploadFailure
        end
      end
    end

    swagger_path '/uploads/{id}' do
      operation :get do
        key :summary, 'Get status for a previous benefits document upload'
        key :operationId, 'getBenefitsDocumentUploadStatus'

        key :tags, [
          'document_uploads'
        ]

        security do
          key :api_key, []
        end

        parameter do
          key :name, 'id'
          key :in, :path
          key :description, 'ID as returned by a previous create upload request'
          key :required, true
          key :example, '6d8433c1-cd55-4c24-affd-f592287a7572'
          key :type, :string
        end

        response 200 do
          key :description, 'Upload status retrieved successfully'
          schema do
            key :required, %i[data]
            property :data do
              key :$ref, :DocumentUploadStatus
            end
          end
        end

        response 401 do
          key :description, 'Unauthorized request'
        end

        response 403 do
          key :description, 'Bad API Token'
        end

        response 404 do
          key :description, 'Not Found'
        end
      end
    end

    swagger_path '/uploads/report' do
      operation :post do
        key :tags, %i[document_uploads]

        key :summary, 'Get a bulk status report for a list of previous uploads'
        key :operationId, 'getBenefitsDocumentUploadStatusReport'

        security do
          key :api_key, []
        end

        parameter do
          key :$ref, :DocumentUploadStatusGuidList
        end

        response 200 do
          key :description, 'Upload status report retrieved successfully'
          schema do
            key :required, %i[data]

            property :data do
              key :$ref, :DocumentUploadStatusReport
            end
          end
        end

        response 400 do
          key :description, 'Bad Request - invalid or missing list of guids'
        end

        response 401 do
          key :description, 'Unauthorized Request'
        end

        response 403 do
          key :description, 'Bad API Token'
        end
      end
    end
  end
end
