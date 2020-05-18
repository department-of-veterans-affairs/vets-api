class V1::Facilities::VaController < FacilitiesController

  # Index supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param type - Optional facility type, values = all (default), health, benefits, cemetery
  # @param services - Optional specialty services filter
  def index
    resource = api.get_facilities(lighthouse_params)

    render json: resource,
           each_serializer: Lighthouse::Facilities::FacilitySerializer,
           meta: metadata(resource)
  end

  def show
    results = api.get_by_id(params[:id])
    raise Common::Exceptions::RecordNotFound, params[:id] if results.nil?

    render json: results, serializer: Lighthouse::Facilities::FacilitySerializer
  end

  private

  def api
    Lighthouse::Facilities::Client.new
  end

  def lighthouse_params
    params.permit 
      :lat, 
      :long,
      :page, 
      :per_page,
      :services,
      :type,
      :zip, 
      bbox: []
  end

  def metadata(resource)
    { 
      pagination: {
        current_page: resource.current_page,
        per_page: resource.per_page,
        total_pages: resource.total_pages,
        total_entries: resource.total_entries 
      }
    }
  end
end
