# frozen_string_literal: true

module V0
  module Benefits
    class DocumentUploadsController < ApplicationController
      include Swagger::Blocks

      # rubocop:disable Metrics/LineLength, Metrics/BlockLength
      swagger_path '/document_uploads' do
        operation :post do
          key :tags, %w[document_uploads]
          key :summary, 'Upload a VA benefits document'
          key :operationId, 'postBenefitsDocumentUpload'
          key :consumes, %w[multipart/form-data]

          parameter do
            key :name, :metadata
            key :description, 'Information about the user and document being submitted. Must conform to the DocumentMetadata model.'
            key :required, true
            key :in, :formData

            schema do
              key :'$ref', :DocumentMetadata
            end
          end
          parameter do
            key :name, :document
            key :description, 'Document contents. Must be provided in PDF format.'
            key :required, true
            key :type, :file
            key :in, :formData
          end
          parameter do
            key :name, :attachment1
            key :description, 'Optional attachment contents. Must be provided in PDF format.'
            key :required, false
            key :type, :file
            key :in, :formData
          end
          parameter do
            key :name, :attachment2
            key :description, 'Optional attachment contents. Must be provided in PDF format.'
            key :required, false
            key :type, :file
            key :in, :formData
          end

          security do
            key :api_key, []
          end

          response 200 do
            key :description, 'Upload received'

            schema do
              property :id, type: :string, description: 'Identifier for subsequent getStatus requests'
            end
          end
        end
      end

      swagger_schema :DocumentMetadata do
        key :required, %i[veteranFirstName veteranLastName fileNumber
                          receiveDate zipCode source uuid docType
                          numberPages hashV numberAttachments]

        property :veteranFirstName, type: :string, example: 'Jane'
        property :veteranLastName, type: :string, example: 'Doe'
        property :fileNumber, type: :string, example: '999887777', description: '8 or 9 digit number'
        property :receiveDate, type: :string, example: '2001-01-01 12:00:00', description: 'Date/time document was received in US Central Time'
        property :zipCode, type: :string, example: '20571'
        property :source, type: :string, example: 'MyApplication', description: 'Your document upload source identifier as defined in developer portal'
        property :uuid, type: :string, example: 'b6571888-48b2-436d-b938-9807d8a2a4ef', description: 'A random unique identifier for this submission'
        property :docType, type: :string, example: 'pension', description: 'Document type, one of "21-22", "526ez"'
        property :numberPages, type: :number, format: :uint32, description: 'Number of pages in main document'
        property :hashV, type: :string, description: 'SHA-256 hash of main document contents'
        property :numberAttachments, type: :number, format: :uint32, description: 'Number of attachments supplied, specify 0 if no attachments'
        property :numberPages1, type: :number, format: :uint32, description: 'Optional, number of pages in first attachment, if present'
        property :ahash1, type: :string, description: 'Optional, SHA-256 hash of first attachment contents, if present'
        property :numberPages2, type: :number, format: :uint32, description: 'Optional, number of pages in second attachment, if present'
        property :ahash2, type: :string, description: 'Optional, SHA-256 hash of second attachment contents, if present'
      end
      # rubocop:enable Metrics/LineLength, Metrics/BlockLength

      def create; end

      swagger_path '/document_uploads/{id}' do
        operation :get do
          key :tags, %w[document_uploads]

          key :summary, 'Get status for a previous benefits document upload'
          key :operationId, 'getBenefitsDocumentUploadStatus'

          parameter do
            key :name, :id
            key :in, :path
            key :description, 'UUID as specified in the metadata of a previous upload'
            key :required, true
            key :type, :string
          end

          security do
            key :api_key, []
          end

          response 200 do
            key :description, 'Upload status retrieved successfully'
            schema do
              property :hello, type: :string
            end
          end
        end
      end
    end
  end
end
