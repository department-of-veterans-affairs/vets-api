# frozen_string_literal: true

require_dependency 'claims_api/form_526_model_swagger'

module ClaimsApi
  module Docs
    module V0
      class ApiController < ::ApplicationController
        skip_before_action(:authenticate)
        include Swagger::Blocks

        # A list of all classes that have swagger_* declarations.
        SWAGGERED_CLASSES = [
          ClaimsApi::ClaimsModelSwagger,
          ClaimsApi::Form526ModelSwagger,
          ClaimsApi::ClaimsV0Swagger
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
