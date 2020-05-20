# frozen_string_literal: true

module VAOS
  module V1
    class OrganizationsController < VAOS::V1::BaseController
      def index
        response = fhir_service.search(query_string)
        render json: response.body
      end

      def show
        response = fhir_service.read(params[:id])
        render json: response.body
      end

      private

      # TODO: move to base controller
      def fhir_service
        VAOS::V1::FHIRService.new(current_user, controller_name.singularize.capitalize.to_sym)
      end
    end
  end
end
