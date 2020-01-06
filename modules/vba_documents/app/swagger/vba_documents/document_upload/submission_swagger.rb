# frozen_string_literal: true

module VbaDocuments
  module DocumentUpload
    class SubmissionSwagger
      include Swagger::Blocks

      swagger_component do
        schema :DocumentUploadSubmission do
          key :description, 'Record of requested document submission. Includes the location to which the document payload is to be uploaded'
          key :required, %i[id type attributes]
          property :id do
            key :description, 'JSON API Identifier'
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
            key :$ref, :DocumentUploadSubmissionAttributes
          end
        end

        schema :DocumentUploadSubmissionAttributes do
          allOf do
            schema do
              key :$ref, :DocumentUploadStatusAttributes
            end
            schema do
              key :type, :object
              key :required, %i[location]

              property :location do
                key :description, 'Location to which to PUT document Payload'
                key :type, :string
                key :format, :uri
                key :example, 'https://dev-api.va.gov/services_content/idpath
      '
              end
            end
          end
        end
      end
    end
  end
end
