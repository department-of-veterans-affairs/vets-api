# frozen_string_literal: true

require 'will_paginate/array'
class V1::Facilities::CcpController < FacilitiesController
  # Provider supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param services - Optional specialty services filter
  def index
    api_results = ppms_search.collect do |result|
      PPMS::Provider.new(
        result.attributes.transform_keys { |k| k.to_s.snakecase.to_sym }
      )
    end.uniq(&:id).paginate(pagination_params)

    render_json(PPMS::ProviderSerializer, ppms_params, api_results, { include: [:specialties] })
  end

  def show
    api_result = api.provider_info(params[:id])

    services = api.provider_services(params[:id])
    api_result.add_provider_service(services[0]) if services.present?

    api_result = PPMS::Provider.new(api_result.attributes.transform_keys { |k| k.to_s.snakecase.to_sym })

    render_json(PPMS::ProviderSerializer, ppms_params, api_result, { include: [:specialties] })
  end

  def specialties
    api_results = api.specialties.collect do |result|
      PPMS::Specialty.new(
        result.transform_keys { |k| k.to_s.snakecase.to_sym }
      )
    end

    render_json(PPMS::SpecialtySerializer, ppms_params, api_results)
  end

  private

  def api
    @api ||= Facilities::PPMS::Client.new
  end

  def ppms_params
    params.permit(
      :address,
      :page,
      :per_page,
      :type,
      bbox: [],
      specialties: []
    )
  end

  def ppms_search
    if ppms_params[:type] == 'provider' && ppms_params[:specialties] == ['261QU0200X']
      api.pos_locator(ppms_params)
    elsif ppms_params[:type] == 'provider'
      provider_search
    elsif ppms_params[:type] == 'pharmacy'
      provider_search(specialties: ['3336C0003X'])
    elsif ppms_params[:type] == 'urgent_care'
      api.pos_locator(ppms_params)
    end
  end

  def provider_search(options = {})
    api.provider_locator(ppms_params.merge(options)).map do |provider|
      begin
        prov_info = api.provider_info(provider['ProviderIdentifier'])
        provider.add_details(prov_info)
      rescue => e
        log_exception_to_sentry(e, { provider_info: provider['ProviderIdentifier'] }, { external_service: :ppms })
      end

      provider
    end
  end

  def resource_path(options)
    v1_facilities_ccp_index_url(options)
  end
end
