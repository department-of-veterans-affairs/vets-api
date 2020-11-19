# frozen_string_literal: true

module HealthQuest
  module V0
    class QuestionnaireResponsesController < HealthQuest::V0::BaseController
      def index
        factory = HealthQuest::PatientGeneratedData::QuestionnaireResponse::Factory.manufacture(current_user)

        render json: factory.all.response[:body]
      end

      def show
        head :ok
      end
    end
  end
end
