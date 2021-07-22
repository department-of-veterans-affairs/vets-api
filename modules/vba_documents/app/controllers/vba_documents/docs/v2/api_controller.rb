# frozen_string_literal: true

require_dependency 'vba_documents/v2/swagger_root'
require_dependency 'vba_documents/document_upload/status_report_swagger'
require_dependency 'vba_documents/document_upload/v1/status_attributes_swagger'
require_dependency 'vba_documents/document_upload/v1/pdf_upload_attributes_swagger'
require_dependency 'vba_documents/document_upload/v1/pdf_dimension_attributes_swagger'

module VBADocuments
  module Docs
    module V2
      class ApiController < ApplicationController
        skip_before_action(:authenticate)
        include Swagger::Blocks

        SWAGGERED_CLASSES = [
          VBADocuments::DocumentUpload::FailureSwagger,
          VBADocuments::DocumentUpload::V2::MetadataSwagger,
          VBADocuments::DocumentUpload::StatusSwagger,
          VBADocuments::DocumentUpload::StatusReportSwagger,
          VBADocuments::DocumentUpload::StatusGuidListSwagger,
          VBADocuments::DocumentUpload::V2::ObserversSwagger,
          VBADocuments::DocumentUpload::SubmissionSwagger,
          VBADocuments::DocumentUpload::UploadSwagger,
          VBADocuments::DocumentUpload::V1::PdfUploadAttributesSwagger,
          VBADocuments::DocumentUpload::V1::PdfDimensionAttributesSwagger,
          VBADocuments::DocumentUpload::V1::StatusAttributesSwagger,
          VBADocuments::DocumentUpload::V2::UploadAttributesSwagger,
          VBADocuments::V2::ControllerSwagger,
          VBADocuments::V2::ErrorModelSwagger,
          VBADocuments::V2::SecuritySchemeSwagger,
          VBADocuments::V2::SwaggerRoot
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
