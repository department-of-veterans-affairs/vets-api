# frozen_string_literal: true

module Veteran
  module Accreditation
    class VSORepresentativesSerializer < BaseRepresentativesSerializer
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
      attribute :poa_codes, array: true
      attribute :phone
      attribute :email
      attribute :lat
      attribute :long
      attribute :distance
      attribute :organization_names

      def organization_names
        object.try(:organization_name)
      end
    end
  end
end
