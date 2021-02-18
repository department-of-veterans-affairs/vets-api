# frozen_string_literal: true

module HealthQuest
  module V0
    class QuestionnaireManagerController < HealthQuest::V0::BaseController
      def index
        data = factory.all

        render json: data
      end

      def create
        data = factory.create_questionnaire_response(questionnaire_response_params).response[:body]

        render json: data
      end

      private

      def questionnaire_response_params
        params.require(:questionnaire_response).permit!
      end

      def factory
        @factory ||= QuestionnaireManager::Factory.manufacture(current_user)
      end
    end
  end
end
