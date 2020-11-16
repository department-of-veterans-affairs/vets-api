# frozen_string_literal: true

module HealthQuest
  module V0
    class QuestionnaireResponsesController < HealthQuest::V0::BaseController
      def show
        head :ok
      end
    end
  end
end
