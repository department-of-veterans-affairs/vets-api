# frozen_string_literal: true

require_dependency 'vba_documents/v1/swagger_root'
require_dependency 'vba_documents/v0/security_scheme_swagger'
require_dependency 'vba_documents/document_upload/status_report_swagger'
require_dependency 'vba_documents/document_upload/v1/status_attributes_swagger'
require_dependency 'vba_documents/document_upload/v1/pdf_upload_attributes_swagger'
require_dependency 'vba_documents/document_upload/v1/pdf_dimension_attributes_swagger'

module VBADocuments
  module Docs
    module V1
      class ApiController < ApplicationController
        skip_before_action(:authenticate)
        include Swagger::Blocks

        SWAGGERED_CLASSES = [
          VBADocuments::V1::ControllerSwagger,
          VBADocuments::V1::ErrorModelSwagger,
          VBADocuments::DocumentUpload::StatusReportSwagger,
          VBADocuments::DocumentUpload::StatusGuidListSwagger,
          VBADocuments::DocumentUpload::FailureSwagger,
          VBADocuments::DocumentUpload::MetadataSwagger,
          VBADocuments::DocumentUpload::V1::StatusAttributesSwagger,
          VBADocuments::DocumentUpload::V1::PdfUploadAttributesSwagger,
          VBADocuments::DocumentUpload::V1::PdfDimensionAttributesSwagger,
          VBADocuments::DocumentUpload::StatusSwagger,
          VBADocuments::DocumentUpload::SubmissionSwagger,
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
