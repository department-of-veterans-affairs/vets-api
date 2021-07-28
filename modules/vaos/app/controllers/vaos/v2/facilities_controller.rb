# frozen_string_literal: true

module VAOS
  module V2
    class FacilitiesController < VAOS::V0::BaseController
      def index
        response = mobile_facility_service.get_facilities(ids: ids,
                                                          children: children,
                                                          type: type)
        render json: VAOS::V2::FacilitiesSerializer.new(response[:data], meta: response[:meta])
      end

      private

      def mobile_facility_service
        VAOS::V2::MobileFacilityService.new(current_user)
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
    end
  end
end
