# frozen_string_literal: true

module HealthQuest
  module V0
    class PgdQuesResponsesController < HealthQuest::V0::BaseController
      def show
        qresponse = ques_response_by_id
        res = serializer.new(qresponse[:data], meta: qresponse[:meta])
        render json: res
      end

      private

      def serializer
        HealthQuest::V0::PGDQuesResponseSerializer
      end

      def ques_response_by_id
        pgd_service.get_pgd_resource(:questionnaire_response, params[:id])
      end

      def pgd_service
        HealthQuest::PGDService.new(current_user)
      end
    end
  end
end
