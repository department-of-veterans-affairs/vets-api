# frozen_string_literal: true

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
