# frozen_string_literal: true

module HealthQuest
  module V0
    class QuestionnaireResponsesController < HealthQuest::V0::BaseController
      def index
        render json: factory.search(params[:filters]).response[:body]
      end

      def show
        render json: factory.get(params[:id]).response[:body]
      end

      def create
        render json: factory.create(params[questionnaire_response]).response[:body]
      end

      private

      def factory
        @factory =
          HealthQuest::PatientGeneratedData::QuestionnaireResponse::Factory.manufacture(current_user)
      end
    end
  end
end
