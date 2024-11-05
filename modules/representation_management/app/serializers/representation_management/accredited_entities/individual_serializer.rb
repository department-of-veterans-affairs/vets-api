# frozen_string_literal: true

module RepresentationManagement
  module AccreditedEntities
    class IndividualSerializer
      include JSONAPI::Serializer

      attributes :first_name, :last_name, :full_name,
                 :address_line1,
                 :address_line2, :address_line3, :address_type,
                 :city, :country_name, :country_code_iso3, :province,
                 :international_postal_code, :state_code, :zip_code, :zip_suffix,
                 :phone, :email,
                 :individual_type

      attribute :accredited_organizations do |object|
        RepresentationManagement::AccreditedIndividuals::OrganizationSerializer.new(object.accredited_organizations)
      end
    end
  end
end
