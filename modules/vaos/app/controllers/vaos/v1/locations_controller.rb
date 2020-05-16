# frozen_string_literal: true

module VAOS
  module V1
    class LocationsController < VAOS::V1::BaseController
      def index
        fhir_service.search(:Location, query_string)
      end

      def show
        fhir_service.read(:Location, params[:id])
      end

      private

      def query_string
        request.fullpath.split('?').last
      end
    end
  end
end
