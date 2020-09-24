# frozen_string_literal: true

module VbaDocuments
  module DocumentUpload
    class FailureSwagger
      include Swagger::Blocks

      swagger_component do
        schema :DocumentUploadFailure do
          key :type, :object
          key :description, 'Document upload failed'

          xml do
            key :name, 'Error'
          end

          property :Code do
            key :type, :string
            key :description, 'Error code'
            key :example, 'Bad Digest'
          end

          property :Message do
            key :type, :string
            key :description, 'Error detail'
            key :example, 'A client error (InvalidDigest) occurred when calling the PutObject operation - The Content-MD5 you specified was invalid.'
          end

          property :Resource do
            key :type, :string
            key :description, 'Resource description'
            key :example, '/vba_documents/6d8433c1-cd55-4c24-affd-f592287a7572.upload'
          end

          property :RequestId do
            key :type, :string
            key :description, 'Identifier for debug purposes'
          end
        end
      end
    end
  end
end
