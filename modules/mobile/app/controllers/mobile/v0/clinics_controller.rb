# frozen_string_literal: true

module Mobile
  module V0
    class ClinicsController < ApplicationController
      def index
        response = systems_service.get_facility_clinics(location_id: params[:facility_id],
                                                        clinical_service: params[:service_type])

        render json: Mobile::V0::ClinicsSerializer.new(response)
      end

      def slots
        start_date = params[:start_date] || now.iso8601
        end_date = params[:end_date] || two_months_from_now.iso8601

        response = systems_service.get_available_slots(location_id: facility_id,
                                                       clinic_id:,
                                                       start_dt: start_date,
                                                       end_dt: end_date)

        render json: Mobile::V0::ClinicSlotsSerializer.new(response)
      end

      private

      def systems_service
        VAOS::V2::SystemsService.new(@current_user)
      end

      def facility_id
        params.require(:facility_id)
      end

      def service_type
        params.require(:service_type)
      end

      def clinic_id
        params.require(:clinic_id)
      end

      def now
        DateTime.now.utc
      end

      def two_months_from_now
        (DateTime.now.utc.end_of_day + 2.months)
      end
    end
  end
end
