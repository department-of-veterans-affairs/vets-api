# frozen_string_literal: true

module RepresentationManagement
  module OriginalEntities
    class RepresentativeSerializer
      include JSONAPI::Serializer

      attributes :first_name, :last_name, :full_name,
                 :address_line1,
                 :address_line2, :address_line3, :address_type,
                 :city, :country_name, :country_code_iso3, :province,
                 :international_postal_code, :state_code, :zip_code, :zip_suffix, :email

      attribute :phone, &:phone_number

      attribute :individual_type do |object|
        object.user_types.first
      end

      attribute :accredited_organizations do |object|
        RepresentationManagement::OriginalEntities::OrganizationSerializer.new(object.organizations)
      end
    end
  end
end
