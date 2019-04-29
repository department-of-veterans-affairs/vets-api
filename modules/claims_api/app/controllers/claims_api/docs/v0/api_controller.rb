# frozen_string_literal: true

require_dependency 'claims_api/form_526_model_swagger'
require_dependency 'claims_api/form_0966_model_swagger'
require_dependency 'claims_api/form_526_v0_controller_swagger'
require_dependency 'claims_api/form_0966_v0_controller_swagger'

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
          ClaimsApi::Form0966ModelSwagger,
          ClaimsApi::ErrorModelSwagger,
          ClaimsApi::ClaimsV0ControllerSwagger,
          ClaimsApi::Form526V0ControllerSwagger,
          ClaimsApi::Form0966V0ControllerSwagger,
          ClaimsApi::ClaimsV0Swagger
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
