# frozen_string_literal: true

module VbaDocuments
  module V1
    class ControllerSwagger
      include Swagger::Blocks

      swagger_path '/uploads' do
        operation :post do
          key :summary, 'Get a location for subsequent document upload PUT request'
          key :operationId, 'postBenefitsDocumentUpload'
          security do
            key :apikey, []
          end
          key :tags, [
            'document_uploads'
          ]

          response 202 do
            key :description, 'Accepted. Location generated'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:data]
                property :data do
                  key :'$ref', :DocumentUploadSubmission
                end
              end
            end
          end

          response 401 do
            key :description, 'Unauthorized Request'
          end

          response 403 do
            key :description, 'Bad API Token'
          end

          response :default do
            key :description, 'unexpected error'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :ErrorModel
                  end
                end
              end
            end
          end
        end
      end

      swagger_path '/path' do
        operation :put do
          key :summary, 'Accepts document upload.'
          key :description, File.read(VBADocuments::Engine.root.join('app', 'swagger', 'vba_documents', 'document_upload', 'put_description.md'))
          key :operationId, 'putBenefitsDocumentUpload'

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

          response 200 do
            key :description, 'Document upload staged'
          end

          response 400 do
            content 'application/xml' do
              schema do
                key :$ref, :DocumentUploadFailure
              end
            end
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
            key :apikey, []
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
            content 'application/json' do
              schema do
                key :required, %i[data]
                property :data do
                  key :$ref, :DocumentUploadStatus
                end
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

          response :default do
            key :description, 'unexpected error'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :ErrorModel
                  end
                end
              end
            end
          end
        end
      end

      swagger_path '/uploads/{id}/download' do
        operation :get do
          key :summary, 'Download zip of "what the server sees"'
          key :description, 'An endpoint that will allow you to see exactly what the server sees. We split apart all submitted docs and metadata and zip the file to make it available to you to help with debugging purposes. Only available in dev and staging'
          key :operationId, 'getBenefitsDocumentUploadDownload'

          key :tags, ['document_uploads']

          security do
            key :apikey, []
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
            key :description, 'Zip file with the contents of your payload as parsed by our server'
            schema do
              key :type, :string
              key :format, :binary
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
            key :apikey, []
          end

          request_body do
            key :description, 'List of GUIDs for which to retrieve current status.'
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

          response 401 do
            key :description, 'Unauthorized Request'
          end

          response 403 do
            key :description, 'Bad API Token'
          end

          response :default do
            key :description, 'unexpected error'
            content 'application/json' do
              schema do
                key :type, :object
                key :required, [:errors]
                property :errors do
                  key :type, :array
                  items do
                    key :'$ref', :ErrorModel
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
