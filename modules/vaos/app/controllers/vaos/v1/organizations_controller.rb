# frozen_string_literal: true

module VAOS
  module V1
    class OrganizationsController < VAOS::V1::BaseController
      def index
        response = fhir_service.search(request.query_string)
        render json: response.body
      end

      def show
        response = fhir_service.read(params[:id])
        render json: response.body
      end
    end
  end
end
