# frozen_string_literal: true

module V0
  class OpenapiController < ApplicationController
    skip_before_action :authenticate
    before_action :check_feature_flag

    def index
      openapi_spec = load_openapi_spec
      render json: openapi_spec
    end

    def show
      openapi_spec = load_openapi_spec
      path = "/#{params[:path]}"

      # Find the specific path in the OpenAPI spec
      path_spec = openapi_spec['paths'][path]

      if path_spec
        render json: {
          path:,
          methods: path_spec
        }
      else
        render json: {
          error: "Path '#{path}' not found",
          available_paths: openapi_spec['paths'].keys
        }, status: :not_found
      end
    end

    private

    def check_feature_flag
      unless Flipper.enabled?(:openapi_docs)
        render json: { error: 'OpenAPI documentation is not enabled' }, status: :not_found
      end
    end

    def load_openapi_spec
      JSON.parse(Rails.public_path.join('openapi.json').read)
    end
  end
end
