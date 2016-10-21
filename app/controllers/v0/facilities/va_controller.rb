# frozen_string_literal: true

class V0::Facilities::VaController < FacilitiesController
  before_action :validate_params, only: [:index]

  # Index supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param type - Optional facility type, values = all (default), health, benefits, cemetery
  # @param services - Optional specialty services filter
  def index
    results = VAFacility.query(bbox: params[:bbox], type: params[:type], services: params[:services])
    render json: results,
           serializer: CollectionSerializer,
           each_serializer: VAFacilitySerializer
  end

  def show
    results = VAFacility.find_by(id: params[:id])
    raise Common::Exceptions::RecordNotFound, params[:id] if results.nil?
    render json: results, serializer: VAFacilitySerializer
  end

  private

  TYPE_SERVICE_ERR = 'Filtering by services is not allowed unless a facility type is specfied'
  def validate_params
    super
    if params[:type].nil? && !params[:services].nil?
      raise Common::Exceptions::ParameterMissing.new('type', detail: TYPE_SERVICE_ERR)
    end
    unless params[:type].nil?
      unless VAFacility::TYPES.include?(params[:type])
        raise Common::Exceptions::InvalidFieldValue.new('type', params[:type])
      end
      unknown = params[:services].to_a - VAFacility.service_whitelist(params[:type])
      raise Common::Exceptions::InvalidFieldValue.new('services', unknown) unless unknown.empty?
    end
  end
end
