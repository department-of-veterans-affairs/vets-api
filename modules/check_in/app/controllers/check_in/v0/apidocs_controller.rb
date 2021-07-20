# frozen_string_literal: true

module CheckIn
  module V0
    class ApidocsController < ApplicationController
      def index
        swagger = YAML.safe_load(File.read(CheckIn::Engine.root.join('app/docs/check_in/v0/check_in.yaml')))

        render json: swagger
      end
    end
  end
end
