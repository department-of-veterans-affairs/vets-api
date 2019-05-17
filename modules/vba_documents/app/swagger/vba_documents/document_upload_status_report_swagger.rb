# frozen_string_literal: true

module VbaDocuments
  class DocumentUploadStatusReportSwagger
    include Swagger::Blocks
    swagger_schema :DocumentUploadStatusReport do
      key :type, :array
      items do
        key :$ref, :DocumentUploadStatus
      end
    end
  end
end
