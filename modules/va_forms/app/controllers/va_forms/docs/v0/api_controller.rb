# frozen_string_literal: true

require_dependency 'va_forms/v0/swagger_root'
# require_dependency 'va_forms/forms_v0_controller_swagger'

module VaForms
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)
        include Swagger::Blocks

        SWAGGERED_CLASSES = [
          VaForms::V0::ControllerSwagger,
          VaForms::V0::SwaggerRoot
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
