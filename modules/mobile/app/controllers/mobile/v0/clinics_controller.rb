# frozen_string_literal: true

module Mobile
  module V0
    class ClinicsController < ApplicationController
      def index
        response = systems_service.get_facility_clinics(location_id: params[:facility_id],
                                                        clinical_service: params[:service_type])

        render json: Mobile::V0::ClinicsSerializer.new(response)
      end

      private

      def systems_service
        VAOS::V2::SystemsService.new(@current_user)
      end
    end
  end
end
