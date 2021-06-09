# frozen_string_literal: true

module ClaimsApi
  module Docs
    module V2
      class ApiController < ClaimsApi::Docs::ApiController
        # SWAGGERED_CLASSES = [
        #   ClaimsApi::Claims::ClaimsResponseSwagger,
        #   ClaimsApi::V2::VeteranIdentifierControllerSwagger,
        #   ClaimsApi::V2::Veterans::ClaimsControllerSwagger,
        #   ClaimsApi::V2::SecuritySchemeSwagger,
        #   ClaimsApi::V2::SwaggerRoot
        # ].freeze

        def index
          # render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
          swagger = JSON.parse(File.read(ClaimsApi::Engine.root.join('app/swagger/claims_api/v2/swagger.json')))
          render json: swagger
        end
      end
    end
  end
end
