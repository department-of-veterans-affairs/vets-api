# frozen_string_literal: true

module HealthQuest
  module V0
    class PgdQuesResponsesController < HealthQuest::V0::BaseController
      def show
        qresponse = ques_response_by_id
        render json: HealthQuest::V0::PGDQuesResponseSerializer.new(qresponse[:data], meta: qresponse[:meta])
      end

      private

      def ques_response_by_id
        pgd_service.get(:questionnaire_response, params[:id])
      end

      def pgd_service
        HealthQuest::PGDService.new(current_user)
      end
    end
  end
end
