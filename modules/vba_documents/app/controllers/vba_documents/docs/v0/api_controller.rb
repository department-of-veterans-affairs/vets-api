# frozen_string_literal: true

require_dependency 'vba_documents/vba_documents_v0_swagger'
require_dependency 'vba_documents/document_upload_status_report_swagger'
require_dependency 'vba_documents/document_upload_status_attributes_swagger'

module VBADocuments
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)
        include Swagger::Blocks

        SWAGGERED_CLASSES = [
          VbaDocuments::VbaDocumentsV0ControllerSwagger,
          VbaDocuments::DocumentUploadStatusReportSwagger,
          VbaDocuments::DocumentUploadStatusGuidListSwagger,
          VbaDocuments::DocumentUploadFailureSwagger,
          VbaDocuments::DocumentUploadMetadataSwagger,
          VbaDocuments::DocumentUploadStatusAttributesSwagger,
          VbaDocuments::DocumentUploadStatusSwagger,
          VbaDocuments::DocumentUploadSubmissionSwagger,
          VbaDocuments::VbaDocumentsV0Swagger
        ].freeze

        def index
          swagger = YAML.safe_load(File.read(VBADocuments::Engine.root.join('README.yml')))
          render json: swagger
        end

        def blocks
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
