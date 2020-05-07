# frozen_string_literal: true

module VAOS
  module V1
    class LocationsController < VAOS::V1::BaseController
      def index
        binding.pry
        fhir_service.search(:Location, search_params)
      end

      private

      def search_params
        params.permit(:name, :identifier, :organization)
      end
    end
  end
end
