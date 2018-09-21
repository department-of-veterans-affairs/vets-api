# frozen_string_literal: true

class V0::Facilities::CcpController < FacilitiesController
  def show
    ppms = Facilities::PPMSClient.new
    id = params[:id][4..-1]
    result = ppms.provider_info(id)
    render json: format_details(result)
  end

  def specialties
    ppms = Facilities::PPMSClient.new
    result = ppms.specialties
    render json: result
  end

  private

  def format_details(prov_info)
    { id: "ccp_#{prov_info['ProviderIdentifier']}", type: 'cc_provider', attributes: {
      unique_id: prov_info['ProviderIdentifier'], name: prov_info['Name'],
      orgName: nil,
      address: { street: prov_info['AddressStreet'], city: prov_info['AddressCity'],
                 state: prov_info['AddressStateProvince'],
                 zip: prov_info['AddressPostalCode'] },
      phone: prov_info['MainPhone'],
      fax: prov_info['OrganizationFax'],
      website: nil,
      prefContact: prov_info['ContactMethod'],
      accNewPatients: prov_info['IsAcceptingNewPatients'],
      gender: prov_info['ProviderGender'],
      network: nil,
      specialty: prov_info['ProviderSpecialties'].map { |specialty| specialty['SpecialtyName'] }
    } }
  end
end
