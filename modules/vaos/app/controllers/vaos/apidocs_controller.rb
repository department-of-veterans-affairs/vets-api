# frozen_string_literal: true

module VAOS
  class ApidocsController < ApplicationController
    skip_before_action(:authenticate)

    def index
      swagger = YAML.safe_load(File.read(VAOS::Engine.root.join('app/docs/v0/vaos.yaml')))
      render json: swagger
    end
  end
end
