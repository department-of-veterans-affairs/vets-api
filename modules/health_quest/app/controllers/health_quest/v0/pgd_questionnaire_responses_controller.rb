# frozen_string_literal: true

module HealthQuest
  module V0
    class PgdQuestionnaireResponsesController < HealthQuest::V0::BaseController
      def show
        head :ok
      end
    end
  end
end
