# frozen_string_literal: true

require 'will_paginate/array'

class V0::Facilities::VaController < FacilitiesController
  TYPE_SERVICE_ERR = 'Filtering by services is not allowed unless a facility type is specified'
  before_action :validate_params, only: [:index]
  before_action :validate_types_name_part, only: [:suggested_names]

  # Index supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param type - Optional facility type, values = all (default), health, benefits, cemetery
  # @param services - Optional specialty services filter
  def index
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

  def suggested_names
    results = BaseFacility.suggested_names(params[:type], params[:name_part])
    render json: results,
           serializer: CollectionSerializer,
           each_serializer: VAFacilitySerializer
  end

  private

  def validate_types_name_part
    raise Common::Exceptions::InvalidFieldValue.new('type', params[:type]) unless
      (BaseFacility::TYPES & params[:type]).present?
    raise Common::Exceptions::ParameterMissing.new('name_part') if params[:name_part].blank?
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
