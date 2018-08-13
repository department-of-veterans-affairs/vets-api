# frozen_string_literal: true

require 'will_paginate/array'

class V0::Facilities::VaController < FacilitiesController
  TYPE_SERVICE_ERR = 'Filtering by services is not allowed unless a facility type is specified'
  before_action :validate_params, only: [:index]
  before_action :validate_types_name_part, only: [:suggested]

  # Index supports the following query parameters:
  # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
  # @param type - Optional facility type, values = all (default), health, benefits, cemetery
  # @param services - Optional specialty services filter
  def index
    resource = BaseFacility.query(params).paginate(page: params[:page], per_page: BaseFacility.per_page)
    render json: resource,
           each_serializer: VAFacilitySerializer,
           meta: metadata(resource)
  end

  def show
    results = BaseFacility.find_facility_by_id(params[:id])
    raise Common::Exceptions::RecordNotFound, params[:id] if results.nil?
    render json: results, serializer: VAFacilitySerializer
  end

  def suggested
    results = BaseFacility.suggested(params[:type], params[:name_part])
    render json: results,
           serializer: CollectionSerializer,
           each_serializer: VASuggestedFacilitySerializer
  end

  def ppms
    params.delete 'action'
    params.delete 'controller'
    params.delete 'format'
    command = params.delete 'Command'
    start = Time.now.utc
    ppms = Facilities::PPMSClient.new.test_routes(command, params)
    finish = Time.now.utc
    ppms = "Latency: #{finish - start}\n" + ppms.to_s
    render text: ppms
  rescue StandardError => e
    render text: "message: #{e&.message} \nbody: #{e&.body} \nppms.url: #{Settings.ppms&.url}"
  end

  def provider_locator
    ppms = Facilities::PPMSClient.new
    providers = ppms.provider_locator(params)
    Rails.logger.info(providers.class.name)
    providers.map! do |provider|
      prov_info = ppms.provider_info(provider['ProviderIdentifier'])
      format_provloc(provider, prov_info)
    end
    render json: { data: providers }
  end

  private

  def validate_types_name_part
    raise Common::Exceptions::ParameterMissing, 'name_part' if params[:name_part].blank?
    raise Common::Exceptions::ParameterMissing, 'type' if params[:type].blank?
    raise Common::Exceptions::InvalidFieldValue.new('type', params[:type]) unless
      (params[:type] - BaseFacility::TYPES).empty?
  end

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

  def validate_type_and_services_known
    raise Common::Exceptions::InvalidFieldValue.new('type', params[:type]) unless
      BaseFacility::TYPES.include?(params[:type])
    unknown = params[:services].to_a - BaseFacility::SERVICE_WHITELIST[params[:type]]
    raise Common::Exceptions::InvalidFieldValue.new('services', unknown) unless unknown.empty?
  end

  def format_provloc(provider, prov_info)
    { id: "ccp_#{provider['ProviderIdentifier']}", type: 'cc_provider', attributes: {
      unique_id: provider['ProviderIdentifier'], name: provider['ProviderName'],
      orgName: '¯\_(ツ)_/¯', lat: provider['Latitude'], long: provider['Longitude'],
      address: { physical: { address1: prov_info['AddressStreet'], city: prov_info['AddressCity'],
                             state: prov_info['AddressStateProvince'],
                             zip: prov_info['AddressPostalCode'] } },
      phone: prov_info['MainPhone'],
      fax: prov_info['OrganizationFax'],
      website: nil,
      prefContact: prov_info['ContactMethod'],
      accNewPatients: provider['ProviderAcceptingNewPatients'],
      gender: provider['ProviderGender'],
      distance: provider['Miles'],
      network: provider['ProviderNetwork'],
      specialty: prov_info['ProviderSpecialties'].map { |specialty| specialty['SpecialtyName'] }
    } }
  end

  def metadata(resource)
    { pagination: { current_page: resource.current_page,
                    per_page: resource.per_page,
                    total_pages: resource.total_pages,
                    total_entries: resource.total_entries } }
  end
end
