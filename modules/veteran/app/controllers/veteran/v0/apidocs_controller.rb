# frozen_string_literal: true

module Veteran
  module V0
    class ApidocsController < ApplicationController
      service_tag 'lighthouse-veteran'
      skip_before_action :authenticate

      def index
        swagger = YAML.safe_load(File.read(Veteran::Engine.root.join('app/docs/veteran/v0/accreditation.yaml')))

        render json: swagger
      end
    end
  end
end
