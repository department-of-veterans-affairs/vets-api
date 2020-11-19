# frozen_string_literal: true

module HealthQuest
  module V0
    class QuestionnaireResponsesController < HealthQuest::V0::BaseController
      def index
        factory = klass.manufacture(current_user)

        render json: factory.search.response[:body]
      end

      def show
        factory = klass.manufacture(current_user)

        render json: factory.get(params[:id]).response[:body]
      end

      private

      def klass
        HealthQuest::PatientGeneratedData::QuestionnaireResponse::Factory
      end
    end
  end
end
