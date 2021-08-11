# frozen_string_literal: true

module VBADocuments
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
            key :example, 'SignatureDoesNotMatch'
          end

          property :Message do
            key :type, :string
            key :description, 'Error detail'
            key :example, 'The request signature we calculated does not match the signature you provided. Check your key and signing method.'
          end
        end
      end
    end
  end
end
