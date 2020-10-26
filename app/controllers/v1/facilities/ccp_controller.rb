# frozen_string_literal: true

require 'will_paginate/array'
require 'facilities/ppms/v0/client'
require 'facilities/ppms/v1/client'

class V1::Facilities::CcpController < FacilitiesController
  # Provider supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param services - Optional specialty services filter
  def index
    api_results = index_api_results

    render_json(PPMS::ProviderSerializer, ppms_params, api_results, { include: [:specialties] })
  end

  def show
    api_result = api.provider_info(ppms_show_params[:id])

    services = api.provider_services(ppms_show_params[:id])
    api_result.add_provider_service(services[0]) if services.present?

    api_result = PPMS::Provider.new(api_result.attributes.transform_keys { |k| k.to_s.snakecase.to_sym })

    render_json(PPMS::ProviderSerializer, ppms_show_params, api_result, { include: [:specialties] })
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
    if Flipper.enabled?(:facility_locator_ppms_use_v1_client)
      index_api_results_v1
    else
      index_api_results_v0
    end
  end

  def index_api_results_v0
    ppms_search.collect do |result|
      PPMS::Provider.new(
        result.attributes.transform_keys { |k| k.to_s.snakecase.to_sym }
      )
    end.paginate(pagination_params)
  end

  def index_api_results_v1
    ppms_search
  end

  def api
    @api ||= if Flipper.enabled?(:facility_locator_ppms_use_v1_client)
               Facilities::PPMS::V1::Client.new
             else
               Facilities::PPMS::V0::Client.new
             end
  end

  def ppms_params
    params.require(%i[bbox type])
    params.permit(
      :address,
      :page,
      :per_page,
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
      provider_search
    elsif ppms_params[:type] == 'pharmacy'
      provider_search(specialties: ['3336C0003X'])
    elsif ppms_params[:type] == 'urgent_care'
      api.pos_locator(ppms_params)
    end
  end

  def provider_search(options = {})
    if Flipper.enabled?(:facility_locator_ppms_use_v1_client)
      provider_search_v1(options)
    else
      provider_search_v0(options)
    end
  end

  def provider_search_v0(options = {})
    api.provider_locator(ppms_params.merge(options)).uniq(&:id).map do |provider|
      begin
        prov_info = api.provider_info(provider.id)
        provider.add_details(prov_info)
      rescue => e
        log_exception_to_sentry(e, { provider_info: provider.id }, { external_service: :ppms })
      end
      provider
    end
  end

  def provider_search_v1(options = {})
    providers = api.provider_locator(ppms_params.merge(options))

    current_page = providers.current_page
    per_page = providers.per_page
    total_entries = providers.total_entries

    providers.map do |provider|
      begin
        prov_info = api.provider_info(provider.id)
        provider.add_details(prov_info)
      rescue => e
        log_exception_to_sentry(e, { provider_info: provider.id }, { external_service: :ppms })
      end
      provider
    end

    WillPaginate::Collection.create(current_page, per_page) do |pager|
      pager.replace(providers)
      pager.total_entries = total_entries
    end
  end

  def resource_path(options)
    v1_facilities_ccp_index_url(options)
  end
end
