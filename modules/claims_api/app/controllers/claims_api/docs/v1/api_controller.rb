# frozen_string_literal: true

require_dependency 'claims_api/v1/form_526_controller_swagger'
require_dependency 'claims_api/v1/form_0966_controller_swagger'
require_dependency 'claims_api/v1/form_2122_controller_swagger'

module ClaimsApi
  module Docs
    module V1
      class ApiController < ClaimsApi::Docs::ApiController
        SWAGGERED_CLASSES = [
          ClaimsApi::Claims::ClaimsResponseSwagger,
          ClaimsApi::Forms::Form526ResponseSwagger,
          ClaimsApi::Forms::Form0966ResponseSwagger,
          ClaimsApi::Forms::Form2122ResponseSwagger,
          ClaimsApi::Common::ErrorModelSwagger,
          ClaimsApi::V1::ClaimsControllerSwagger,
          ClaimsApi::V1::Form526ControllerSwagger,
          ClaimsApi::V1::Form0966ControllerSwagger,
          ClaimsApi::V1::Form2122ControllerSwagger,
          ClaimsApi::V1::SwaggerRoot
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
