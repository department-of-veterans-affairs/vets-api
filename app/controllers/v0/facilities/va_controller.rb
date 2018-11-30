# frozen_string_literal: true

require 'will_paginate/array'

class V0::Facilities::VaController < FacilitiesController
  TYPE_SERVICE_ERR = 'Filtering by services is not allowed unless a facility type is specified'
  before_action :validate_params, only: [:index]
  before_action :validate_types_name_part, only: [:suggested]

  # Index supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param type - Optional facility type, values = all (default), health, benefits, cemetery
  # @param services - Optional specialty services filter
  def index
    # this first return is temporary for the rollout of provider locator to staging
    return facilities unless Settings.locators.providers_enabled

    return facilities if BaseFacility::TYPES.include?(params[:type]) || params[:address].nil?
    return provider_locator if params[:type] == 'cc_provider'
    combined
  end

  def facilities
    resource = BaseFacility.query(params).paginate(page: params[:page], per_page: BaseFacility.per_page)
    render json: resource,
           each_serializer: VAFacilitySerializer,
           meta: metadata(resource)
  end

  def combined
    resource = BaseFacility.query(params)
    ppms = Facilities::PPMSClient.new
    providers = ppms.provider_locator(params)
    bbox_num = params[:bbox].map { |x| Float(x) }
    page = Integer(params[:page] || 1)
    total = resource.length + providers.length
    sorted = Provider.merge(resource, providers, (bbox_num[0] + bbox_num[2]) / 2,
                            (bbox_num[1] + bbox_num[3]) / 2, page * BaseFacility.per_page)
    sorted = sorted[(page - 1) * BaseFacility.per_page, BaseFacility.per_page]
    sorted.map! { |row| format_records(row, ppms) }
    pages = { current_page: page, per_page: BaseFacility.per_page,
              total_pages: total / BaseFacility.per_page, total_entries: total }
    render json: { data: sorted, meta: { pagination: pages } }
  end

  def show
    results = BaseFacility.find_facility_by_id(params[:id])
    raise Common::Exceptions::RecordNotFound, params[:id] if results.nil?
    render json: results, serializer: VAFacilitySerializer
  end

  def suggested
    results = BaseFacility.suggested(params[:type], params[:name_part])
    render json: results,
           serializer: CollectionSerializer,
           each_serializer: VASuggestedFacilitySerializer
  end

  def provider_locator
    ppms = Facilities::PPMSClient.new
    providers = ppms.provider_locator(params)
    page = 1
    page = Integer(params[:page]) if params[:page]
    total = providers.length
    start_ind = (page - 1) * BaseFacility.per_page
    providers = providers[start_ind, BaseFacility.per_page - 1]
    providers.map! do |provider|
      prov_info = ppms.provider_info(provider['ProviderIdentifier'])
      provider.add_details(prov_info)
      provider
    end
    pages = { current_page: page, per_page: BaseFacility.per_page,
              total_pages: total / BaseFacility.per_page + 1, total_entries: total }

    render json: providers,
           each_serializer: ProviderSerializer,
           meta: { pagination: pages }
  end

  private

  def format_records(record, ppms)
    if record.is_a?(BaseFacility)
      ser = VAFacilitySerializer.new(record)
      { id: ser.id, type: 'vha_facility', name: record[:name], attributes: ser.as_json }
    else
      prov_info = ppms.provider_info(record['ProviderIdentifier'])
      record.add_details(prov_info)
      prov_ser = ProviderSerializer.new(record)
      { id: prov_ser.id, type: 'cc_provider', name: record[:Name], attributes: prov_ser.as_json }
    end
  end

  def validate_types_name_part
    raise Common::Exceptions::ParameterMissing, 'name_part' if params[:name_part].blank?
    raise Common::Exceptions::ParameterMissing, 'type' if params[:type].blank?
    raise Common::Exceptions::InvalidFieldValue.new('type', params[:type]) unless
      (params[:type] - BaseFacility::TYPES).empty?
  end

  def validate_params
    super
    validate_no_services_without_type
    validate_type_and_services_known unless params[:type].nil?
  end

  def validate_no_services_without_type
    if params[:type].nil? && !params[:services].nil?
      raise Common::Exceptions::ParameterMissing.new('type', detail: TYPE_SERVICE_ERR)
    end
  end

  def validate_type_and_services_known
    return if params[:type] == 'cc_provider'
    raise Common::Exceptions::InvalidFieldValue.new('type', params[:type]) unless
      BaseFacility::TYPES.include?(params[:type])
    unknown = params[:services].to_a - BaseFacility::SERVICE_WHITELIST[params[:type]]
    raise Common::Exceptions::InvalidFieldValue.new('services', unknown) unless unknown.empty?
  end

  def metadata(resource)
    { pagination: { current_page: resource.current_page,
                    per_page: resource.per_page,
                    total_pages: resource.total_pages,
                    total_entries: resource.total_entries } }
  end
end
