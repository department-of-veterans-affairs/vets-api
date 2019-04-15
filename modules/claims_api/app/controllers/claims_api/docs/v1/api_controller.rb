# frozen_string_literal: true

require_dependency 'claims_api/form_526_model_swagger'

module ClaimsApi
  module Docs
    module V1
      class ApiController < ::ApplicationController
        skip_before_action(:authenticate)
        # skip_before_action(:log_request)
        include Swagger::Blocks

        # A list of all classes that have swagger_* declarations.
        SWAGGERED_CLASSES = [
          ClaimsApi::ClaimsModelSwagger,
          ClaimsApi::Form526ModelSwagger,
          ClaimsApi::ClaimsV1Swagger
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
