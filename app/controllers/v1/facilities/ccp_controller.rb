# frozen_string_literal: true

require 'will_paginate/array'
require 'facilities/ppms/v1/client'

class V1::Facilities::CcpController < FacilitiesController
  # Provider supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param services - Optional specialty services filter
  def index
    api_results = index_api_results

    render_json(PPMS::ProviderSerializer, ppms_params, api_results)
  end

  def show
    api_result = api.provider_info(ppms_show_params[:id])

    services = api.provider_services(ppms_show_params[:id])
    api_result.add_provider_service(services[0]) if services.present?

    api_result = PPMS::Provider.new(api_result.attributes.transform_keys { |k| k.to_s.snakecase.to_sym })

    render_json(PPMS::ProviderSerializer, ppms_show_params, api_result)
  end

  def specialties
    api_results = api.specialties.collect do |result|
      PPMS::Specialty.new(
        result.transform_keys { |k| k.to_s.snakecase.to_sym }
      )
    end

    render_json(PPMS::SpecialtySerializer, params, api_results)
  end

  private

  def index_api_results
    ppms_search
  end

  def api
    @api ||= Facilities::PPMS::V1::Client.new
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

  def ppms_provider_params
    params.require(:type)
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

  def ppms_show_params
    params.permit(:id)
  end

  def ppms_search
    if ppms_params[:type] == 'provider' && ppms_params[:specialties] == ['261QU0200X']
      api.pos_locator(ppms_params)
    elsif ppms_params[:type] == 'provider'
      api.provider_locator(ppms_provider_params)
    elsif ppms_params[:type] == 'pharmacy'
      api.provider_locator(ppms_params.merge(specialties: ['3336C0003X']))
    elsif ppms_params[:type] == 'urgent_care'
      api.pos_locator(ppms_params)
    end
  end

  def resource_path(options)
    v1_facilities_ccp_index_url(options)
  end
end
