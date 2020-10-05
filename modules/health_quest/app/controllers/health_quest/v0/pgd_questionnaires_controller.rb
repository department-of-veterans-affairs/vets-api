# frozen_string_literal: true

module HealthQuest
  module V0
    class PgdQuestionnairesController < HealthQuest::V0::BaseController
      def show
        ques = questionnaire_by_id
        render json: HealthQuest::V0::PGDQuestionnaireSerializer.new(ques[:data], meta: ques[:meta])
      end

      private

      def questionnaire_by_id
        pgd_service.get_pgd_resource(:questionnaire, params[:id])
      end

      def pgd_service
        HealthQuest::PGDService.new(current_user)
      end
    end
  end
end
