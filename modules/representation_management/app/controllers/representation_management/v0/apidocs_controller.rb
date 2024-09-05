# frozen_string_literal: true

module RepresentationManagement
  module V0
    class ApidocsController < ApplicationController
      service_tag 'representation-management'
      skip_before_action :authenticate

      def index
        swagger = YAML.safe_load(File.read(RepresentationManagement::Engine.root.join('app/docs/representation_management/v0/power_of_attorney.yaml'))) # rubocop:disable Layout/LineLength

        render json: swagger
      end
    end
  end
end
