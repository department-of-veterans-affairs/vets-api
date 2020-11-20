# frozen_string_literal: true

require 'will_paginate/array'
require 'facilities/ppms/v0/client'

class V0::Facilities::VaController < FacilitiesController
  TYPE_SERVICE_ERR = 'Filtering by services is not allowed unless a facility type is specified'
  before_action :validate_params, only: [:index]
  before_action :validate_types_name_part, only: [:suggested]

  # Index supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param type - Optional facility type, values = all (default), health, benefits, cemetery
  # @param services - Optional specialty services filter
  def index
    return provider_locator if params[:type] == 'cc_provider'

    facilities
  end

  def facilities
    resource = BaseFacility.query(params).paginate(page: params[:page], per_page: BaseFacility.per_page)
    render json: resource,
           each_serializer: VAFacilitySerializer,
           meta: metadata(resource)
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
    ppms = Facilities::PPMS::V0::Client.new
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

  def api
    Lighthouse::Facilities::Client.new
  end

  def lighthouse_params
    params.permit :lat, :long, :page, :per_page, :services, :type, :zip, bbox: []
  end

  def validate_types_name_part
    raise Common::Exceptions::ParameterMissing, 'name_part' if params[:name_part].blank?
    raise Common::Exceptions::ParameterMissing, 'type' if params[:type].blank?
    raise Common::Exceptions::InvalidFieldValue.new('type', params[:type]) unless
      (params[:type] - BaseFacility::TYPES).empty?
  end

  def validate_params
    super
    params.delete(:type) if params[:type] == 'all'
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

    unknown = params[:services].to_a - facility_klass.service_list
    raise Common::Exceptions::InvalidFieldValue.new('services', unknown) unless unknown.empty?
  end

  def metadata(resource)
    { pagination: { current_page: resource.current_page,
                    per_page: resource.per_page,
                    total_pages: resource.total_pages,
                    total_entries: resource.total_entries } }
  end

  def facility_klass
    BaseFacility::TYPE_MAP[params[:type]].constantize
  end
end
