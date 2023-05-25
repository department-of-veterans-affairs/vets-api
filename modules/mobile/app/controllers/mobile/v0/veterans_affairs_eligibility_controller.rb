# frozen_string_literal: true

module Mobile
  module V0
    class VeteransAffairsEligibilityController < ApplicationController
      def show
        data = mobile_facility_service.get_scheduling_configurations(facility_ids)[:data]
        services = medical_service_adapter.parse(data)

        render json: Mobile::V0::VeteransAffairsEligibilitySerializer.new(@current_user.uuid, services,
                                                                          cc_supported_facility_ids(data))
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

      def cc_supported_facility_ids(service_eligibilities)
        service_eligibilities.select(&:community_care)&.map(&:facility_id)
      end
    end
  end
end
