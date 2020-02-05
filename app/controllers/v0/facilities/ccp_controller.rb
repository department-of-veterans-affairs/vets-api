# frozen_string_literal: true

class V0::Facilities::CcpController < FacilitiesController
  before_action :validate_id, only: [:show]

  def index
    raise Common::Exceptions::ParameterMissing.new('type', detail: TYPE_SERVICE_ERR) if params[:type].nil?

    ppms_results =  case search_params[:type]
                    when 'cc_provider'
                      provider_search
                    when 'cc_pharmacy'
                      provider_search('services' => ['3336C0003X'])
                    when 'cc_walkin'
                      api.pos_locator(search_params, '17')
                    when 'cc_urgent_care'
                      api.pos_locator(search_params, '20')
                    end

    start_ind = (page - 1) * BaseFacility.per_page
    ppms_results = ppms_results[start_ind, BaseFacility.per_page - 1]

    render  json: ppms_results,
            each_serializer: ProviderSerializer,
            meta: { pagination: pages(ppms_results) }
  end

  def show
    result = api.provider_info(params[:id])
    raise Common::Exceptions::RecordNotFound, params[:id] if result.nil?

    services = api.provider_services(params[:id])
    result.add_provider_service(services[0]) if services.present?
    render json: result, serializer: ProviderSerializer
  end

  def services
    result = api.specialties
    render json: result
  end

  private

  def search_params
    params.permit(:type, :address, services: [], bbox: [])
  end

  def provider_search(options = {})
    api.provider_locator(search_params.merge(options)).map do |provider|
      prov_info = api.provider_info(provider['ProviderIdentifier'])
      provider.add_details(prov_info)
      provider
    end
  end

  def api
    @api ||= Facilities::PPMS::Client.new
  end

  def page
    Integer(params[:page] || 1)
  end

  def pages(ppms_results)
    total = ppms_results.length
    {
      current_page: page,
      per_page: BaseFacility.per_page,
      total_pages: Integer(ppms_results.length / BaseFacility.per_page + 1),
      total_entries: total
    }
  end

  def validate_id
    if /^ccp_/.match?(params[:id])
      params[:id] = params[:id].sub(/^ccp_/, '')
    else
      raise Common::Exceptions::InvalidFieldValue.new('id', params[:id])
    end
  end
end
