# frozen_string_literal: true

require 'common/models/collection'
require 'will_paginate/array'

class Vbeta::Facilities::VaController < FacilitiesController
  before_action :validate_params, only: [:index]

  # Index supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param type - Optional facility type, values = all (default), health, benefits, cemetery
  # @param services - Optional specialty services filter
  def index
    resource = BaseFacility.query(params).paginate
    render json: resource.data,
           serializer: CollectionSerializer,
           each_serializer: VAFacilitySerializer,
           meta: resource.metadata
  end

  def show
    results = BaseFacility.find_facility_by_id(params[:id])
    raise Common::Exceptions::RecordNotFound, params[:id] if results.nil?
    render json: results, serializer: VAFacilitySerializer
  end

  # just for testing/validation, will not stay long term
  def all
    mappings = { 'va_cemetery' => 'nca',
                 'va_benefits_facility' => 'vba',
                 'vet_center' => 'vc',
                 'va_health_facility' => 'vha' }
    render json: BaseFacility.pluck(:unique_id, :facility_type).map { |id, type| "#{mappings[type]}_#{id}" }.to_json
  end

  private

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

  TYPE_SERVICE_ERR = 'Filtering by services is not allowed unless a facility type is specified'
  def validate_type_and_services_known
    raise Common::Exceptions::InvalidFieldValue.new('type', params[:type]) unless
      BaseFacility::TYPES.include?(params[:type])
    unknown = params[:services].to_a - BaseFacility.service_whitelist(params[:type])
    raise Common::Exceptions::InvalidFieldValue.new('services', unknown) unless unknown.empty?
  end
end
