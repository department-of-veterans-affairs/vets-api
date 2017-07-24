# frozen_string_literal: true
require 'common/models/form'

module Preneeds
  class Address < Preneeds::Base
    attribute :address1, String
    attribute :address2, String
    attribute :address3, String
    attribute :city, String
    attribute :country_code, String
    attribute :postal_zip, String
    attribute :state, String

    # Hash attributes must correspond to xsd ordering or API call will fail
    def message
      hash = {
        address1: address1, address2: address2, address3: address3, city: city,
        countryCode: country_code, postalZip: postal_zip, state: state
      }

      [:address2, :address3].each { |key| hash.delete(key) if hash[key].nil? }
      hash
    end

    def self.permitted_params
      attribute_set.map { |a| a.name.to_sym }
    end
  end
end
