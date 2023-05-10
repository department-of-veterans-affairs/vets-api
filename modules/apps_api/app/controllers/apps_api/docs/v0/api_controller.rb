# frozen_string_literal: true

module AppsApi
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)
        include Swagger::Blocks

        SWAGGERED_CLASSES = [
          AppsApi::V0::ControllerSwagger,
          AppsApi::V0::Apps::AppsSwagger,
          AppsApi::V0::SwaggerRoot
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
