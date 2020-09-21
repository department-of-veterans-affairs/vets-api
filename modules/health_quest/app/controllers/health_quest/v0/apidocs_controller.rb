# frozen_string_literal: true

module HealthQuest
  module V0
    class ApidocsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        swagger = YAML.safe_load(File.read(HealthQuest::Engine.root.join('app/docs/health_quest/v0/health_quest.yaml')))
        render json: swagger
      end
    end
  end
end
