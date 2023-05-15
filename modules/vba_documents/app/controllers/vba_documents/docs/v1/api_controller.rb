# frozen_string_literal: true

module VBADocuments
  module Docs
    module V1
      class ApiController < ApplicationController
        skip_before_action(:authenticate)
        include Swagger::Blocks

        SWAGGERED_CLASSES = [
          VBADocuments::DocumentUpload::FailureSwagger,
          VBADocuments::DocumentUpload::V1::MetadataSwagger,
          VBADocuments::DocumentUpload::StatusSwagger,
          VBADocuments::DocumentUpload::StatusReportSwagger,
          VBADocuments::DocumentUpload::StatusGuidListSwagger,
          VBADocuments::DocumentUpload::SubmissionSwagger,
          VBADocuments::DocumentUpload::UploadSwagger,
          VBADocuments::DocumentUpload::ValidateDocumentSwagger,
          VBADocuments::DocumentUpload::V1::PdfUploadAttributesSwagger,
          VBADocuments::DocumentUpload::V1::PdfDimensionAttributesSwagger,
          VBADocuments::DocumentUpload::V1::StatusAttributesSwagger,
          VBADocuments::DocumentUpload::V1::UploadAttributesSwagger,
          VBADocuments::V1::ControllerSwagger,
          VBADocuments::V1::ErrorModelSwagger,
          VBADocuments::V1::SecuritySchemeSwagger,
          VBADocuments::V1::SwaggerRoot
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
