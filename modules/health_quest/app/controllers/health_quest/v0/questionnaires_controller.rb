# frozen_string_literal: true

module HealthQuest
  module V0
    class QuestionnairesController < HealthQuest::V0::BaseController
      def index
        render json: factory.search(request.query_parameters).response[:body]
      end

      def show
        render json: factory.get(params[:id]).response[:body]
      end

      private

      def factory
        @factory =
          PatientGeneratedData::Questionnaire::Factory.manufacture(current_user)
      end
    end
  end
end
