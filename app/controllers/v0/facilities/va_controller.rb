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
    if BaseFacility::TYPES.include?(params[:type])
      resource = BaseFacility.query(params).paginate(page: params[:page], per_page: BaseFacility.per_page)
      render json: resource,
             each_serializer: VAFacilitySerializer,
             meta: metadata(resource)
    elsif params[:type] == 'cc_provider'
      provider_locator
    else
      combined
    end
  end

  def combined
    resource = BaseFacility.query(params)
    ppms = Facilities::PPMSClient.new
    providers = ppms.provider_locator(params)
    bbox_num = params[:bbox].map { |x| Float(x) }
    page = Integer(params[:page] || 1)
    total = resource.length + providers.length
    sorted = merge(resource, providers, (bbox_num[0] + bbox_num[2]) / 2,
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
    Rails.logger.info(providers.class.name)
    page = 1
    page = Integer(params[:page]) if params[:page]
    total = providers.length
    start_ind = (page - 1) * BaseFacility.per_page
    providers = providers[start_ind, BaseFacility.per_page - 1]
    providers.map! do |provider|
      prov_info = ppms.provider_info(provider['ProviderIdentifier'])
      format_provloc(provider, prov_info)
    end
    # paging currently not possible
    pages = { current_page: page, per_page: BaseFacility.per_page,
              total_pages: total / BaseFacility.per_page, total_entries: total }

    render json: { data: providers, meta: { pagination: pages } }
  end

  private

  def format_records(record, ppms)
    if record.is_a?(BaseFacility)
      ser = VAFacilitySerializer.new(record)
      { id: ser.id, name: record[:name], attributes: ser.as_json }
    else
      prov_info = ppms.provider_info(record['ProviderIdentifier'])
      format_provloc(record, prov_info)
    end
  end

  def merge(facilities, providers, center_x, center_y, limit)
    distance_facilities = facilities.map do |facility|
      { distance: 69 * Math.sqrt((facility.long - center_x)**2 + (facility.lat - center_y)**2),
        facility: facility }
    end
    result = []
    facility_ind = 0
    provider_ind = 0
    limit = facilities.length + providers.length if limit > facilities.length + providers.length
    while result.length < limit
      a = provider_ind < providers.length
      b = facility_ind >= distance_facilities.length
      if a && (b || distance_facilities[facility_ind][:distance] > providers[provider_ind]['Miles'])
        result.push providers[provider_ind]
        provider_ind += 1
      else
        result.push distance_facilities[facility_ind][:facility]
        facility_ind += 1
      end
    end
    result
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
    raise Common::Exceptions::InvalidFieldValue.new('type', params[:type]) unless
      BaseFacility::TYPES.include?(params[:type]) || params[:type] == 'cc_provider'
    unknown = params[:services].to_a - BaseFacility::SERVICE_WHITELIST[params[:type]]
    raise Common::Exceptions::InvalidFieldValue.new('services', unknown) unless unknown.empty?
  end

  def format_provloc(provider, prov_info)
    { id: "ccp_#{provider['ProviderIdentifier']}", type: 'cc_provider', attributes: {
      unique_id: provider['ProviderIdentifier'], name: provider['ProviderName'],
      orgName: '¯\_(ツ)_/¯', lat: provider['Latitude'], long: provider['Longitude'],
      address: { street: prov_info['AddressStreet'], city: prov_info['AddressCity'],
                 state: prov_info['AddressStateProvince'],
                 zip: prov_info['AddressPostalCode'] },
      phone: prov_info['MainPhone'],
      fax: prov_info['OrganizationFax'],
      website: nil,
      prefContact: prov_info['ContactMethod'],
      accNewPatients: provider['ProviderAcceptingNewPatients'],
      gender: provider['ProviderGender'],
      distance: provider['Miles'],
      network: provider['ProviderNetwork'],
      specialty: prov_info['ProviderSpecialties'].map { |specialty| specialty['SpecialtyName'] }
    } }
  end

  def metadata(resource)
    { pagination: { current_page: resource.current_page,
                    per_page: resource.per_page,
                    total_pages: resource.total_pages,
                    total_entries: resource.total_entries } }
  end
end
