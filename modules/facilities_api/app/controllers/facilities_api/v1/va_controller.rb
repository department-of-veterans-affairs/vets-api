# frozen_string_literal: true

require 'lighthouse/facilities/client'

module FacilitiesApi
  class V1::VAController < ApplicationController
    # Index supports the following query parameters:
    # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
    # @param type - Optional facility type, values = all (default), health, benefits, cemetery
    # @param services - Optional specialty services filter
    def index
      api_results = api.get_facilities(lighthouse_params)

      if Flipper.enabled?(:facilities_locator_mobile_covid_online_scheduling) && covid_mobile_params?
        api_results.each do |api_result|
          api_result.tmp_covid_online_scheduling = mobile_api_get_by_id(api_result.id)
        end
      end

      render_json(serializer, lighthouse_params, api_results)
    end

    def show
      api_result = api.get_by_id(params[:id])

      render_json(serializer, lighthouse_params, api_result)
    end

    private

    def api
      FacilitiesApi::V1::Lighthouse::Client.new
    end

    def lighthouse_params
      params.permit(
        :ids,
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
      FacilitiesApi::V1::Lighthouse::FacilitySerializer
    end

    def resource_path(options)
      v1_va_index_url(options)
    end

    def mobile_api
      FacilitiesApi::V1::MobileCovid::Client.new
    end

    def mobile_api_get_by_id(id)
      mobile_api.direct_booking_eligibility_criteria_by_id(id).covid_online_scheduling_available?
    end

    def covid_mobile_params?
      lighthouse_params.fetch(:type, '')[/health/i] && lighthouse_params[:services]&.any?(/Covid19Vaccine/i)
    end
  end
end
