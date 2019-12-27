# frozen_string_literal: true

require_dependency 'vba_documents/v1/swagger_root'
require_dependency 'vba_documents/v0/security_scheme_swagger'
require_dependency 'vba_documents/document_upload/status_report_swagger'
require_dependency 'vba_documents/document_upload/v1/status_attributes_swagger'

module VBADocuments
  module Docs
    module V1
      class ApiController < ApplicationController
        skip_before_action(:authenticate)
        include Swagger::Blocks

        SWAGGERED_CLASSES = [
          VbaDocuments::V1::ControllerSwagger,
          VbaDocuments::V1::ErrorModelSwagger,
          VbaDocuments::DocumentUpload::StatusReportSwagger,
          VbaDocuments::DocumentUpload::StatusGuidListSwagger,
          VbaDocuments::DocumentUpload::FailureSwagger,
          VbaDocuments::DocumentUpload::MetadataSwagger,
          VbaDocuments::DocumentUpload::V1::StatusAttributesSwagger,
          VbaDocuments::DocumentUpload::StatusSwagger,
          VbaDocuments::DocumentUpload::SubmissionSwagger,
          VbaDocuments::V1::SecuritySchemeSwagger,
          VbaDocuments::V1::SwaggerRoot
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
