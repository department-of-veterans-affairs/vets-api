# frozen_string_literal: true

module HealthQuest
  module V1
    class AppointmentsController < HealthQuest::V1::BaseController
      def index
        response = fhir_service.search(request.query_string)
        render json: response.body
      end
    end
  end
end
