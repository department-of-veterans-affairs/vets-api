# frozen_string_literal: true

module RepresentationManagement
  module AccreditedEntities
    class IndividualSerializer
      include JSONAPI::Serializer

      attributes :first_name, :last_name,
                 :address_line1,
                 :address_line2, :address_line3, :address_type,
                 :city, :country_name, :country_code_iso3, :province,
                 :international_postal_code, :state_code, :zip_code, :zip_suffix,
                 :phone, :email,
                 # Do we need these two for this serializer?
                 :individual_type, :registration_number

      attribute :accredited_organizations do |object|
        # OrganizationSerializer.new(object.accredited_organizations)
        RepresentationManagement::AccreditedIndividuals::OrganizationSerializer.new(object.accredited_organizations)
      end
    end
  end
end
