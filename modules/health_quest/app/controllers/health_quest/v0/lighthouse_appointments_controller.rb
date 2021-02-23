# frozen_string_literal: true

module HealthQuest
  module V0
    class LighthouseAppointmentsController < HealthQuest::V0::BaseController
      def index
        render json: []
      end

      def show
        render json: {}
      end
    end
  end
end
