# frozen_string_literal: true

require_dependency 'facilities_api/application_controller'

module FacilitiesApi
  class V1::CcpController < ApplicationController
    # Provider supports the following query parameters:
    # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
    # @param services - Optional specialty services filter
    def index
      api_results = ppms_search

      render_json(V1::PPMS::ProviderSerializer, ppms_params, api_results)
    end

    def urgent_care
      api_results = api.pos_locator(ppms_action_params)

      render_json(V1::PPMS::ProviderSerializer, ppms_action_params, api_results)
    end

    def provider
      api_results = if provider_urgent_care?
                      api.pos_locator(ppms_action_params)
                    else
                      api.provider_locator(ppms_provider_params)
                    end

      render_json(V1::PPMS::ProviderSerializer, ppms_action_params, api_results)
    end

    def pharmacy
      api_results = api.provider_locator(ppms_action_params.merge(specialties: ['3336C0003X']))

      render_json(V1::PPMS::ProviderSerializer, ppms_action_params, api_results)
    end

    def specialties
      api_results = api.specialties.collect do |result|
        V1::PPMS::Specialty.new(
          result.transform_keys { |k| k.to_s.snakecase.to_sym }
        )
      end

      render_json(V1::PPMS::SpecialtySerializer, params, api_results)
    end

    private

    def api
      @api ||= FacilitiesApi::V1::PPMS::Client.new
    end

    def ppms_params
      params.require(:type)
      params.permit(
        :address,
        :latitude,
        :longitude,
        :page,
        :per_page,
        :radius,
        :type,
        bbox: [],
        specialties: []
      )
    end

    def ppms_action_params
      params.permit(
        :address,
        :latitude,
        :longitude,
        :page,
        :per_page,
        :radius,
        bbox: [],
        specialties: []
      )
    end

    def ppms_provider_params
      params.require(:specialties)
      params.permit(
        :address,
        :latitude,
        :longitude,
        :page,
        :per_page,
        :radius,
        :type,
        bbox: [],
        specialties: []
      )
    end

    def ppms_search
      if urgent_care?
        api.pos_locator(ppms_params)
      elsif ppms_params[:type] == 'provider'
        api.provider_locator(ppms_provider_params)
      elsif ppms_params[:type] == 'pharmacy'
        api.provider_locator(ppms_params.merge(specialties: ['3336C0003X']))
      end
    end

    def urgent_care?
      (ppms_params[:type] == 'provider' && provider_urgent_care?) || ppms_params[:type] == 'urgent_care'
    end

    def provider_urgent_care?
      ppms_provider_params[:specialties] == ['261QU0200X']
    end

    def resource_path(options)
      v1_ccp_index_url(options)
    end
  end
end
