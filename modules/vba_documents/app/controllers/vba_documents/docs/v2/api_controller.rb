# frozen_string_literal: true

module VBADocuments
  module Docs
    module V2
      class ApiController < ApplicationController
        skip_before_action(:authenticate)
        include Swagger::Blocks

        SWAGGERED_CLASSES = [
          VBADocuments::V2::ControllerSwagger
        ].freeze

        def index
          render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
        end
      end
    end
  end
end
