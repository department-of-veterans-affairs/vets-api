# frozen_string_literal: true

require_dependency 'va_forms/v0/swagger_root'
require_dependency 'va_forms/v0/security_scheme_swagger'
require_dependency 'va_forms/forms/form_swagger'

module VaForms
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)
        include Swagger::Blocks

        SWAGGERED_CLASSES = [
          VaForms::V0::ControllerSwagger,
          VaForms::Forms::Form,
          VaForms::V0::SecuritySchemeSwagger,
          VaForms::V0::SwaggerRoot
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
