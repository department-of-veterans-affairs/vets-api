# frozen_string_literal: true

module MebApi
  module V0
    class ApidocsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        swagger = YAML.safe_load(File.read(MebApi::Engine.root.join('app/docs/dgi/v0/dgi_v0.yaml')))
        render json: swagger
      end
    end
  end
end
