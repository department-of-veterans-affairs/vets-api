# frozen_string_literal: true

module HealthQuest
  module V0
    class QuestionnaireResponsesController < HealthQuest::V0::BaseController
      def index
        render json: factory.search(request.query_parameters).response[:body]
      end

      def show
        render json: factory.get(params[:id]).response[:body]
      end

      def create
        render json: factory.create(questionnaire_response_params).response[:body]
      end

      private

      def questionnaire_response_params
        params.require(:questionnaire_response).permit!
      end

      def factory
        HealthQuest::Resource::Factory.manufacture(
          user: current_user,
          resource_identifier: 'questionnaire_response',
          api: Settings.hqva_mobile.lighthouse.pgd_api
        )
      end
    end
  end
end
