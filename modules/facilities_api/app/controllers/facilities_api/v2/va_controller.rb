# frozen_string_literal: true

module FacilitiesApi
  class V2::VAController < ApplicationController
    skip_before_action :verify_authenticity_token

    def search
      params[:facilityIds] = params[:ids] if params[:ids].present?
      api_results = api.get_facilities(lighthouse_params)

      render_json(serializer, lighthouse_params, api_results)
    end

    def show
      api_result = api.get_by_id(params[:id])

      render_json(serializer, lighthouse_params, api_result)
    end

    private

    def api
      FacilitiesApi::V2::Lighthouse::Client.new
    end

    def lighthouse_params
      map_latitude_longitude_params_to_lat_long
      params.permit(
        :ids,
        :facilityIds,
        :lat,
        :long,
        :mobile,
        :page,
        :per_page,
        :radius,
        :state,
        :type,
        :visn,
        :zip,
        bbox: [],
        services: []
      )
    end

    def serializer
      FacilitiesApi::V2::Lighthouse::FacilitySerializer
    end

    def resource_path(options)
      v2_va_search_url(options)
    end

    def mobile_api
      FacilitiesApi::V2::MobileCovid::Client.new
    end

    def mobile_api_get_by_id(id)
      mobile_api.direct_booking_eligibility_criteria_by_id(id).covid_online_scheduling_available?
    end

    def covid_mobile_params?
      lighthouse_params.fetch(:type, '')[/health/i] && lighthouse_params[:services]&.any?(/Covid19Vaccine/i)
    end

    # Mapbox prepares the params with latitude and longitude, but the Lighthouse API
    # is only prepared to process lat and long
    def map_latitude_longitude_params_to_lat_long
      params[:lat] = params[:latitude] if params[:latitude].present? && params[:lat].blank?
      params[:long] = params[:longitude] if params[:longitude].present? && params[:long].blank?
    end
  end
end
