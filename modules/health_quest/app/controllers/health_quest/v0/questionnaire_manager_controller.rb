# frozen_string_literal: true

module HealthQuest
  module V0
    class QuestionnaireManagerController < HealthQuest::V0::BaseController
      def index
        data = factory.all

        render json: data
      end

      private

      def factory
        @factory ||= QuestionnaireManager::Factory.manufacture(current_user)
      end
    end
  end
end
