# frozen_string_literal: true

module VAOS
  module V1
    class HealthcareServicesController < VAOS::V1::BaseController
      def index
        response = fhir_service.search(query_string)
        render json: response.body
      end

      private

      def query_string
        request.fullpath.split('?').last
      end
    end
  end
end
