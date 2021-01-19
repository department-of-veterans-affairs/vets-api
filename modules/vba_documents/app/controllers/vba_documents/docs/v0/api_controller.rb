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
          VBADocuments::V0::ControllerSwagger,
          VBADocuments::DocumentUpload::StatusReportSwagger,
          VBADocuments::DocumentUpload::StatusGuidListSwagger,
          VBADocuments::DocumentUpload::FailureSwagger,
          VBADocuments::DocumentUpload::MetadataSwagger,
          VBADocuments::DocumentUpload::StatusAttributesSwagger,
          VBADocuments::DocumentUpload::StatusSwagger,
          VBADocuments::DocumentUpload::SubmissionSwagger,
          VBADocuments::V0::SecuritySchemeSwagger,
          VBADocuments::V0::SwaggerRoot
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
