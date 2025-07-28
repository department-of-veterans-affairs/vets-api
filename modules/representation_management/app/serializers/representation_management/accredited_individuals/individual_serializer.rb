# frozen_string_literal: true

module RepresentationManagement
  module AccreditedIndividuals
    class IndividualSerializer
      include JSONAPI::Serializer

      attributes :individual_type, :registration_number, :first_name, :last_name, :address_line1,
                 :address_line2, :address_line3, :address_type, :city, :country_name, :country_code_iso3, :province,
                 :international_postal_code, :state_code, :zip_code, :zip_suffix, :phone, :email,
                 :lat, :long

      attribute :full_name do |object|
        "#{object.first_name} #{object.last_name}"
      end

      attribute :distance do |object|
        object.distance / AccreditedRepresentation::Constants::METERS_PER_MILE
      end

      attribute :accredited_organizations do |object|
        OrganizationSerializer.new(object.accredited_organizations)
      end
    end
  end
end
