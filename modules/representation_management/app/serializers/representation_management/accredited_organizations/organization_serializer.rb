# frozen_string_literal: true

module RepresentationManagement
  module AccreditedOrganizations
    class OrganizationSerializer
      include JSONAPI::Serializer

      set_id :poa_code
      set_type :accredited_organization

      attributes :poa_code, :name, :phone, :city, :state_code, :zip_code, :zip_suffix,
                 :can_accept_digital_poa_requests
    end
  end
end
