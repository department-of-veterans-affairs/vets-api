# frozen_string_literal: true

module CheckIn
  module V2
    class ApidocsController < CheckIn::ApplicationController
      skip_before_action :authorize

      def index
        swagger = YAML.safe_load(File.read(CheckIn::Engine.root.join('app/docs/check_in/v2/check_in.yaml')))

        render json: swagger
      end
    end
  end
end
