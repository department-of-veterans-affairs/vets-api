# frozen_string_literal: true

require 'lighthouse/facilities/client'

class V1::Facilities::VaController < FacilitiesController
  # Index supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param type - Optional facility type, values = all (default), health, benefits, cemetery
  # @param services - Optional specialty services filter
  def index
    api_results = api.get_facilities(lighthouse_params)

    render_json(serializer, lighthouse_params, api_results)
  end

  def show
    api_result = api.get_by_id(params[:id])

    render_json(serializer, lighthouse_params, api_result)
  end

  private

  def api
    Lighthouse::Facilities::Client.new
  end

  def lighthouse_params
    params.permit(
      :ids,
      :lat,
      :long,
      :page,
      :per_page,
      :state,
      :type,
      :zip,
      bbox: [],
      services: []
    )
  end

  def serializer
    Lighthouse::Facilities::FacilitySerializer
  end

  def resource_path(options)
    v1_facilities_va_index_url(options)
  end
end
