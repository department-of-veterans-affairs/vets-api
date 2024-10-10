# frozen_string_literal: true

module RepresentationManagement
  module V0
    class ApidocsController < ApplicationController
      service_tag 'representation-management'

      skip_before_action :authenticate

      def index
        swagger = JSON.parse(File.read(RepresentationManagement::Engine.root.join('app/swagger/v0/swagger.json')))
        render json: swagger
      end
    end
  end
end
