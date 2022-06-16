# frozen_string_literal: true

module VAOS
  module V2
    class ApidocsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        swagger_yaml = YAML.safe_load(File.read(VAOS::Engine.root.join('app/docs/vaos/v2/vaos_v2.yaml')))
        swagger = JSON.pretty_generate(swagger_yaml)
        render json: swagger
      end
    end
  end
end
