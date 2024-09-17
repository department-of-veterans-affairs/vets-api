# frozen_string_literal: true

module RepresentationManagement
  module AccreditedIndividuals
    class OrganizationSerializer
      include JSONAPI::Serializer

      attributes :poa_code, :name, :address_line1, :address_line2, :address_line3, :address_type,
                 :city, :country_name, :country_code_iso3, :province, :international_postal_code, :state_code,
                 :zip_code, :zip_suffix, :phone, :lat, :long
    end
  end
end
