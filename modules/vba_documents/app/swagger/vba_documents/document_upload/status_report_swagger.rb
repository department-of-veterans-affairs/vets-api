# frozen_string_literal: true

module VBADocuments
  module DocumentUpload
    class StatusReportSwagger
      include Swagger::Blocks
      swagger_component do
        schema :DocumentUploadStatusReport do
          key :type, :array
          items do
            key :$ref, :DocumentUploadStatus
          end
        end
      end
    end
  end
end
