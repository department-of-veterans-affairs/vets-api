# frozen_string_literal: true

module RepresentationManagement
  module AccreditedEntities
    class OrganizationSerializer
      include JSONAPI::Serializer

      attributes :name,
                 :address_line1, :address_line2, :address_line3, :address_type,
                 :city, :country_name, :country_code_iso3, :province,
                 :international_postal_code, :state_code,
                 :zip_code, :zip_suffix, :phone,
                 # Do we need these for this serializer?
                 :lat, :long, :poa_code
    end
  end
end
