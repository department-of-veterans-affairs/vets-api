# frozen_string_literal: true

module FacilitiesApi
  class V2::CcpController < ApplicationController
    include FacilitiesApi::V2::FacilitiesErrorHandler
    # Provider supports the following query parameters:
    # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
    # @param services - Optional specialty services filter
    def index
      api_results = ppms_search

      render_json(V2::PPMS::ProviderSerializer, ppms_params, api_results)
    end

    def urgent_care
      api_results = api.pos_locator(ppms_action_params)

      render_json(V2::PPMS::ProviderSerializer, ppms_action_params, api_results)
    end

    def provider
      api_results = if provider_urgent_care?
                      api.pos_locator(ppms_action_params)
                    else
                      api.provider_locator(ppms_provider_params)
                    end
      render_json(V2::PPMS::ProviderSerializer, ppms_action_params, api_results)
    end

    def pharmacy
      api_results = provider_locator(ppms_action_params.merge(specialties: ['3336C0003X']))

      render_json(V2::PPMS::ProviderSerializer, ppms_action_params, api_results)
    end

    def specialties
      api_results = api.specialties

      render_json(V2::PPMS::SpecialtySerializer, params, api_results)
    end

    private

    def api
      @api ||= FacilitiesApi::V2::PPMS::Client.new
    end

    def ppms_params
      params.require(:type)
      params.permit(
        :lat,
        :latitude,
        :long,
        :longitude,
        :page,
        :per_page,
        :radius,
        :type,
        specialties: []
      )
    end

    def ppms_action_params
      params.permit(
        :lat,
        :latitude,
        :long,
        :longitude,
        :page,
        :per_page,
        :radius,
        specialties: []
      )
    end

    def ppms_provider_params
      params.require(:specialties)
      params.permit(
        :lat,
        :latitude,
        :long,
        :longitude,
        :page,
        :per_page,
        :radius,
        :type,
        specialties: []
      )
    end

    def ppms_search
      if urgent_care?
        api.pos_locator(ppms_params)
      elsif ppms_params[:type] == 'provider'
        provider_locator(ppms_provider_params)
      elsif ppms_params[:type] == 'pharmacy'
        provider_locator(ppms_params.merge(specialties: ['3336C0003X']))
      end
    end

    def urgent_care?
      (ppms_params[:type] == 'provider' && provider_urgent_care?) || ppms_params[:type] == 'urgent_care'
    end

    def provider_urgent_care?
      ppms_provider_params[:specialties] == ['261QU0200X']
    end

    def resource_path(options)
      v2_ccp_index_url(options)
    end

    def provider_locator(locator_params)
      api.facility_service_locator(locator_params)
    end
  end
end
