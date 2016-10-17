# frozen_string_literal: true

class V0::Facilities::HealthController < FacilitiesController
  before_action :validate_params, only: [:index]

  # Index supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param type - Optional facility type, values = all (default), health, benefits, cemetery
  # @param services - Optional specialty services filter
  def index
    results = VAHealthFacility.query(bbox: params[:bbox], services: params[:services])
    render json: results,
           serializer: CollectionSerializer,
           each_serializer: VAHealthFacilitySerializer
  end

  def show
    results = VAHealthFacility.find_by_id(id: params[:id])
    raise Common::Exceptions::RecordNotFound, params[:id] if results.nil?
    render json: results, serializer: VAHealthFacilitySerializer
  end

  private

  def validate_params
    validate_bbox
    unknown = params[:services].to_a - VAHealthFacility.service_whitelist
    raise Common::Exceptions::InvalidFieldValue.new('services', unknown) unless unknown.empty?
  end
end
