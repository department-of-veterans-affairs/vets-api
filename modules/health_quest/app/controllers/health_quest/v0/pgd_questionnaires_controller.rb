# frozen_string_literal: true

module HealthQuest
  module V0
    class PgdQuestionnairesController < HealthQuest::V0::BaseController
      def show
        ques = questionnaire_by_id
        res = serializer.new(ques[:data], meta: ques[:meta])
        render json: res
      end

      private

      def questionnaire_by_id
        pgd_service.get_pgd_resource(:questionnaire, params[:id])
      end

      def pgd_service
        HealthQuest::PGDService.new(current_user)
      end

      def serializer
        HealthQuest::V0::PGDQuestionnaireSerializer
      end
    end
  end
end
