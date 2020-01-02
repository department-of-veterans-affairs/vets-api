# frozen_string_literal: true

require_dependency 'vba_documents/v0/swagger_root'
require_dependency 'vba_documents/v0/security_scheme_swagger'
require_dependency 'vba_documents/document_upload/status_report_swagger'
require_dependency 'vba_documents/document_upload/status_attributes_swagger'

module VBADocuments
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)
        include Swagger::Blocks

        SWAGGERED_CLASSES = [
          VbaDocuments::V0::ControllerSwagger,
          VbaDocuments::DocumentUpload::StatusReportSwagger,
          VbaDocuments::DocumentUpload::StatusGuidListSwagger,
          VbaDocuments::DocumentUpload::FailureSwagger,
          VbaDocuments::DocumentUpload::MetadataSwagger,
          VbaDocuments::DocumentUpload::StatusAttributesSwagger,
          VbaDocuments::DocumentUpload::StatusSwagger,
          VbaDocuments::DocumentUpload::SubmissionSwagger,
          VbaDocuments::V0::SecuritySchemeSwagger,
          VbaDocuments::V0::SwaggerRoot
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
