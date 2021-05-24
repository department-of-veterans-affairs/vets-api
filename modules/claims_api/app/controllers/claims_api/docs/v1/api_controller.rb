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
          ClaimsApi::Common::Authorization::NotAuthorizedSwagger,
          ClaimsApi::Common::Authorization::ForbiddenSwagger,
          ClaimsApi::Common::NotFoundSwagger,
          ClaimsApi::Common::UnprocessableEntitySwagger,
          ClaimsApi::V1::ClaimsControllerSwagger,
          ClaimsApi::V1::Form526ControllerSwagger,
          ClaimsApi::V1::Form0966ControllerSwagger,
          ClaimsApi::V1::Form2122ControllerSwagger,
          ClaimsApi::V1::SecuritySchemeSwagger,
          ClaimsApi::V1::SwaggerRoot
        ].freeze
        RWSAG_DOCS_ENABLED = Settings.claims_api.rswag_docs.enabled

        def index
          if RWSAG_DOCS_ENABLED
            swagger = JSON.parse(File.read(ClaimsApi::Engine.root.join('app/swagger/v1/swagger.json')))
            render json: swagger
          else
            render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
          end
        end
      end
    end
  end
end
