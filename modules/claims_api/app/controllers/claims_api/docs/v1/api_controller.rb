# frozen_string_literal: true

require_dependency 'claims_api/form_526_model_swagger'
require_dependency 'claims_api/form_0966_model_swagger'
require_dependency 'claims_api/form_526_v1_controller_swagger'
require_dependency 'claims_api/form_0966_v1_controller_swagger'

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
          ClaimsApi::Form0966ModelSwagger,
          ClaimsApi::Form2122ModelSwagger,
          ClaimsApi::ErrorModelSwagger,
          ClaimsApi::ClaimsV1ControllerSwagger,
          ClaimsApi::Form526V1ControllerSwagger,
          ClaimsApi::Form0966V1ControllerSwagger,
          ClaimsApi::Form2122V1ControllerSwagger,
          ClaimsApi::ClaimsV1Swagger
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
