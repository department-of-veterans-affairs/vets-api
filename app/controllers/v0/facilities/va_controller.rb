class V0::Facilities::VaController < FacilitiesController

  # Index supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param type - Optional facility type, values = all (default), health, benefits, cemetery
  # @param services - Optional specialty services filter
  def index
    results = VAHealthFacility.query(bbox: params[:bbox])
    render json: results,
                 serializer: CollectionSerializer,
                 each_serializer: VAHealthFacilitySerializer
  end

  def show
    results = VAHealthFacility.find_by_id(id: params[:id])
    raise VA::API::Common::Exceptions::RecordNotFound, params[:id] if results.nil?
    render json: results, serializer: VAHealthFacilitySerializer
  end

  protected

end
