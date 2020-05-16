# frozen_string_literal: true

module VAOS
  module V1
    class OrganizationsController < VAOS::V1::BaseController
      def show
        response = fhir_service.read(:Organization, params[:id])
        render json: response.body
      end
    end
  end
end
