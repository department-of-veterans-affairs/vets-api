# frozen_string_literal: true

module VAOS
  module V2
    class FacilitiesController < VAOS::BaseController
      def index
        response = mobile_facility_service.get_facilities(ids:,
                                                          children:,
                                                          type:,
                                                          schedulable:)
        render json: VAOS::V2::FacilitiesSerializer.new(response[:data], meta: response[:meta])
      end

      def show
        render json: VAOS::V2::FacilitiesSerializer.new(facility)
      end

      private

      def mobile_facility_service
        VAOS::V2::MobileFacilityService.new(current_user)
      end

      def facility
        @facility ||=
          mobile_facility_service.get_facility(facility_id)
      end

      def facility_id
        params[:facility_id]
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('facility_id', params[:facility_id])
      end

      def ids
        ids = params.require(:ids)
        ids.is_a?(Array) ? ids.to_csv(row_sep: nil) : ids
      end

      def children
        params[:children]
      end

      def type
        params[:type]
      end

      def schedulable
        params[:schedulable]
      end
    end
  end
end
