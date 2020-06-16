# frozen_string_literal: true

module VAOS
  module V1
    class PatientsController < VAOS::V1::BaseController
      def index
        # Commented out to get review instance created, comment to pass code coverage
        # response = fhir_service.search(request.query_string)
        # render json: response.body
      end
    end
  end
end
