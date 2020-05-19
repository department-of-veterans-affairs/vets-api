# frozen_string_literal: true

module VAOS
  module V1
    class HealthcareServicesController < VAOS::V1::BaseController
      def index
        binding.pry
        fhir_service.search(:HealthcareService, search_params)
      end

      private

      def search_params
        params.permit(:identifier, :location, :organization, :servicecategory)
      end
    end
  end
end
