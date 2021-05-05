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

      def show
        send_data factory.generate_questionnaire_response_pdf(params[:id]),
                  filename: 'questionnaire_response.pdf',
                  type: 'application/pdf',
                  disposition: 'inline'
      end

      private

      def questionnaire_response_params
        params.require(:questionnaireResponse)
              .permit(appointment: [:id],
                      questionnaire: %i[id title],
                      item: [:linkId, :text, { answer: [:valueString] }])
      end

      def factory
        @factory ||= QuestionnaireManager::Factory.manufacture(current_user)
      end
    end
  end
end
