# frozen_string_literal: true

module Mobile
  module V0
    class LocationsController < ApplicationController
      def show
        Rails.logger.info('Mobile Location', param_id: params[:id])

        lh_location = service.get_location(params[:id])
        Rails.logger.info('Mobile Location, Lighthouse Info', lh_location:)
        if lh_location[:identifier].nil?
          raise Common::Exceptions::BackendServiceException, 'validation_errors_bad_request'
        end

        id = lh_location[:identifier].first[:value][4..6]
        Rails.logger.info('Mobile Location, Location ID', location_id: id)

        facility = Mobile::FacilitiesHelper.get_facilities([id])
        Rails.logger.info('Mobile Location, Facility Info', facility: facility.first)
        raise Common::Exceptions::BackendServiceException, 'LIGHTHOUSE_FACILITIES404' if facility.first.nil?

        parsed_result = locations_adapter.parse(facility.first, params[:id])
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
