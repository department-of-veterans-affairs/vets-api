# frozen_string_literal: true

module VAOS
  module V1
    class AppointmentsController < VAOS::V1::BaseController
      def index
        response = fhir_service.search(request.query_string)
        render json: response.body
      end

      def create
        response = fhir_service.create(body: request.body.read)
        render json: response.body, status: response.status
      end

      def update
        response = fhir_service.update(id: params[:id], body: request.body.read)
        render json: response.body, status: response.status
      end
    end
  end
end
