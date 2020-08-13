# frozen_string_literal: true

module HealthQuest
  module V0
    class HealthQuestController < ApplicationController
      skip_before_action :authenticate

      def index
        message = service.get_message
        render json: HealthQuestSerializer.new(message).serialized_json
      end

      private

      def service
        Service.new
      end
    end
  end
end
