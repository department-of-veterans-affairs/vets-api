# frozen_string_literal: true

module ClaimsApi
  module Docs
    module V0
      class ApiController < ClaimsApi::Docs::ApiController
        SWAGGERED_CLASSES = [
          ClaimsApi::Claims::ClaimsResponseSwagger,
          ClaimsApi::Forms::Form526ResponseSwagger,
          ClaimsApi::Forms::Form0966ResponseSwagger,
          ClaimsApi::Forms::Form2122ResponseSwagger,
          ClaimsApi::Common::ErrorModelSwagger,
          ClaimsApi::V0::ClaimsControllerSwagger,
          ClaimsApi::V0::Form526ControllerSwagger,
          ClaimsApi::V0::Form0966ControllerSwagger,
          ClaimsApi::V0::Form2122ControllerSwagger,
          ClaimsApi::V0::SwaggerRoot
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
