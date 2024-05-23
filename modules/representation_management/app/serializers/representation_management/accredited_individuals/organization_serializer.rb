# frozen_string_literal: true

module RepresentationManagement
  module AccreditedIndividuals
    class OrganizationSerializer < ActiveModel::Serializer
      attribute :poa_code
      attribute :name
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
      attribute :lat
      attribute :long
    end
  end
end
