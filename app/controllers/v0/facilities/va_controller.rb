# frozen_string_literal: true

require 'common/models/collection'

class V0::Facilities::VaController < FacilitiesController
  before_action :validate_params, only: [:index]

  # Index supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param type - Optional facility type, values = all (default), health, benefits, cemetery
  # @param services - Optional specialty services filter
  def index
    results = []
    if params[:bbox]
      results = VAFacility.query(bbox: params[:bbox], type: params[:type], services: params[:services])
    end
    resource = Common::Collection.new(::VAFacility, data: results)
    resource = resource.paginate(pagination_params)
    render json: resource.data,
           serializer: CollectionSerializer,
           each_serializer: VAFacilitySerializer,
           meta: resource.metadata
  end

  def show
    results = VAFacility.find_by(id: params[:id])
    raise Common::Exceptions::RecordNotFound, params[:id] if results.nil?
    render json: results, serializer: VAFacilitySerializer
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
      VAFacility::TYPES.include?(params[:type])
    unknown = params[:services].to_a - VAFacility.service_whitelist(params[:type])
    raise Common::Exceptions::InvalidFieldValue.new('services', unknown) unless unknown.empty?
  end
end
