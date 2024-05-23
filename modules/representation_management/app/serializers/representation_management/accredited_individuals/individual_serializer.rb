# frozen_string_literal: true

module RepresentationManagement
  module AccreditedIndividuals
    class IndividualSerializer < ActiveModel::Serializer
      attribute :individual_type
      attribute :registration_number
      attribute :full_name
      attribute :address_line1
      attribute :address_line2
      attribute :address_line3
      attribute :address_type
      attribute :city
      attribute :country_name
      attribute :country_code_iso3
      attribute :province
      attribute :international_postal_code
      attribute :state_code
      attribute :zip_code
      attribute :zip_suffix
      attribute :phone
      attribute :email
      attribute :lat
      attribute :long
      attribute :distance
      attribute :accredited_organizations

      def distance
        object.distance / AccreditedRepresentation::Constants::METERS_PER_MILE
      end

      def accredited_organizations
        ActiveModelSerializers::SerializableResource.new(object.accredited_organizations,
                                                         each_serializer: OrganizationSerializer)
      end
    end
  end
end
