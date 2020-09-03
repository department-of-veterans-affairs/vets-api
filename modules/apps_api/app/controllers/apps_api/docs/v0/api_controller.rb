# frozen_string_literal: true

require_dependency 'apps_api/v0/swagger_root'
# require_dependency 'apps_api/v0/security_scheme_swagger'
require_dependency 'apps_api/v0/apps/apps_swagger'

module AppsApi
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)
        include Swagger::Blocks

        SWAGGERED_CLASSES = [
          AppsApi::V0::ControllerSwagger,
          AppsApi::Apps::App,
          AppsApi::V0::SwaggerRoot
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
