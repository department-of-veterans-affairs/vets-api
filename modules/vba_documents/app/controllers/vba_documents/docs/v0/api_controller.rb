# frozen_string_literal: true

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
