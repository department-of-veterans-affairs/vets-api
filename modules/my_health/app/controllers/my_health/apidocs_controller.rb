# frozen_string_literal: true

module MyHealth
  class ApidocsController < MyHealth::ApplicationController
    service_tag 'mhv-messaging'
    skip_before_action :authenticate

    def index
      permitted_classes = [Time] # Allow the Time class to be deserialized
      swagger = YAML.safe_load(
        File.read(MyHealth::Engine.root.join('docs/openapi_merged.yaml')),
        permitted_classes:
      )

      render json: swagger
    end
  end
end
