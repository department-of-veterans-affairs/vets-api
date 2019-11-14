# frozen_string_literal: true

require_dependency 'va_forms/forms_v0_controller_swagger'

module VaForms
  module Docs
    module V0
      class ApiController < VaForms::Docs::ApiController
        SWAGGERED_CLASSES = [
          VaForms::FormModelSwagger,
          VaForms::FormsV0ControllerSwagger
        ].freeze

        def index
          # render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
          Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
          render json: {}
        end
      end
    end
  end
end
