# frozen_string_literal: true

require_dependency 'va_forms/v0/swagger_root'
require_dependency 'va_forms/v0/security_scheme_swagger'
require_dependency 'va_forms/forms/form_swagger'

module VAForms
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)
        include Swagger::Blocks

        SWAGGERED_CLASSES = [
          VAForms::V0::ControllerSwagger,
          VAForms::Forms::Form,
          VAForms::V0::SecuritySchemeSwagger,
          VAForms::V0::SwaggerRoot
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
