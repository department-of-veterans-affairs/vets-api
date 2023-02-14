# frozen_string_literal: true

## VAOS V0 routes and controllers no longer in use
# :nocov:
module VAOS
  module V0
    class ApidocsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        swagger = YAML.safe_load(File.read(VAOS::Engine.root.join('app/docs/vaos/v0/vaos.yaml')))
        render json: swagger
      end
    end
  end
end
# :nocov:
