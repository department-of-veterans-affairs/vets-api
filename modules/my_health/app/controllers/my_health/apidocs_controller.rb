# frozen_string_literal: true

module MyHealth
  class ApidocsController < MyHealth::ApplicationController
    skip_before_action :authenticate

    def index
      swagger = YAML.safe_load(File.read(MyHealth::Engine.root.join('docs/openapi_merged.yaml')))

      render json: swagger
    end
  end
end
