# frozen_string_literal: true

require 'common/models/form'

module Preneeds
  class Address < Preneeds::Base
    attribute :street, String
    attribute :street2, String
    attribute :city, String
    attribute :country, String
    attribute :state, String
    attribute :postal_code, String

    # Hash attributes must correspond to xsd ordering or API call will fail
    def as_eoas
      hash = {
        address1: street, address2: street2, city: city,
        countryCode: country, postalZip: postal_code, state: state
      }

      hash.delete(:address2) if hash[:address2].blank?
      hash
    end

    def self.permitted_params
      attribute_set.map { |a| a.name.to_sym }
    end
  end
end
