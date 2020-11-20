# frozen_string_literal: true

module HealthQuest
  module V0
    class QuestionnaireResponsesController < HealthQuest::V0::BaseController
      before_action :factory

      def index
        render json: @factory.search.response[:body]
      end

      def show
        render json: @factory.get(params[:id]).response[:body]
      end

      private

      def factory
        @factory =
          HealthQuest::PatientGeneratedData::QuestionnaireResponse::Factory.manufacture(current_user)
      end
    end
  end
end
