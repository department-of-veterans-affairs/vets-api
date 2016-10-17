# frozen_string_literal: true

class V0::Facilities::CemeteryController < FacilitiesController
  before_action :validate_params, only: [:index]

  # Index supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param type - Optional facility type, values = all (default), health, benefits, cemetery
  def index
    results = VACemeteryFacility.query(bbox: params[:bbox])
    render json: results,
           serializer: CollectionSerializer,
           each_serializer: VACemeteryFacilitySerializer
  end

  def show
    results = VACemeteryFacility.find_by_id(id: params[:id])
    raise Common::Exceptions::RecordNotFound, params[:id] if results.nil?
    render json: results, serializer: VACemeteryFacilitySerializer
  end

  private

  def validate_params
    validate_bbox
  end
end
