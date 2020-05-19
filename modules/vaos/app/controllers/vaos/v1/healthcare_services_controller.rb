# frozen_string_literal: true

module VAOS
  module V1
    class HealthcareServicesController < VAOS::V1::BaseController
      def index
        fhir_service.search(:HealthcareService, query_string)
      end

      private

      def query_string
        request.fullpath.split('?').last
      end
    end
  end
end
