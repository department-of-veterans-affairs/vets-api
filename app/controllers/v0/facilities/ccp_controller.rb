# frozen_string_literal: true

class V0::Facilities::CcpController < FacilitiesController
  before_action :validate_id, only: [:show]

  ##
  #
  # Urgent Care:261QU0200X
  # Community/Retail Pharmacy:3336C0003X

  EXCLUDED_PROVIDER_TYPES = %w[261QU0200X 3336C0003X].freeze

  def show
    ppms = Facilities::PPMSClient.new
    result = ppms.provider_info(params[:id])
    raise Common::Exceptions::RecordNotFound, params[:id] if result.nil?

    services = ppms.provider_services(params[:id])
    result.add_provider_service(services[0]) if services.present?
    render json: result, serializer: ProviderSerializer
  end

  def services
    ppms = Facilities::PPMSClient.new
    result = ppms.specialties.reject { |item| EXCLUDED_PROVIDER_TYPES.include? item['SpecialtyCode'] }
    render json: result
  end

  private

  def validate_id
    if /^ccp_/.match?(params[:id])
      params[:id] = params[:id].sub(/^ccp_/, '')
    else
      raise Common::Exceptions::InvalidFieldValue.new('id', params[:id])
    end
  end
end
