# frozen_string_literal: true

module Mobile
  module V0
    class VeteransAffairsEligibilityController < ApplicationController
      def show
        response = mobile_facility_service.get_scheduling_configurations(facility_ids)
        services = medical_service_adapter.parse(response[:data])

        render json: Mobile::V0::VeteransAffairsEligibilitySerializer.new(@current_user.id, services)
      end

      private

      def medical_service_adapter
        Mobile::V0::Adapters::MedicalService.new
      end

      def mobile_facility_service
        VAOS::V2::MobileFacilityService.new(@current_user)
      end

      def facility_ids
        ids = params.require(:facilityIds)
        ids.join(',')
      end
    end
  end
end
