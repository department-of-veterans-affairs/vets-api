# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class LocationsController < ApplicationController
      def show
        lh_location = service.get_location(params[:id])
        id = lh_location[:identifier].first[:value][4..]
        facility = Mobile::FacilitiesHelper.get_facilities([id])
        raise Common::Exceptions::BackendServiceException, 'LIGHTHOUSE_FACILITIES404' if facility[0].nil?

        parsed_result = locations_adapter.parse(facility[0], params[:id])
        render json: Mobile::V0::LocationSerializer.new(parsed_result)
      end

      private

      def locations_adapter
        Mobile::V0::Adapters::Locations.new
      end

      def service
        Mobile::V0::LighthouseHealth::Service.new(@current_user)
      end
    end
  end
end
