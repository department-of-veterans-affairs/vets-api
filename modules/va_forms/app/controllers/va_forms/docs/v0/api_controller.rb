# frozen_string_literal: true

module VAForms
  module Docs
    module V0
      class ApiController < ApplicationController
        skip_before_action(:authenticate)
        include Swagger::Blocks

        SWAGGERED_CLASSES = [
          VAForms::V0::ControllerSwagger,
          VAForms::Forms::FormSwagger,
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
