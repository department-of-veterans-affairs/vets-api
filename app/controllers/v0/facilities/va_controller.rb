class V0::Facilities::VaController < FacilitiesController

  # Index supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param type - Optional facility type, values = all (default), health, benefits, cemetery
  # @param services - Optional specialty services filter
  def index
    results = client.query(bbox: params[:bbox])
    render json: results
  end

  def show
    results = client.get(identifier: params[:id])
    render json: results
  end

  protected

  URL = "https://maps.va.gov/server/rest/services/PROJECTS/Facility_Locator/MapServer"
  LAYER = 0
  ID_FIELD = "StationID"

  def client
    puts URL
    puts LAYER
    @client ||= Facilities::Client.new(url: URL, layer: LAYER, id_field: ID_FIELD)
  end
end
