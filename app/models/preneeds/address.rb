# frozen_string_literal: true

module Preneeds
  # Models an address from a {Preneeds::BurialForm} form
  #
  # @!attribute street
  #   @return [String] address line 1
  # @!attribute street2
  #   @return [String] address line 2
  # @!attribute city
  #   @return [String] address city
  # @!attribute country
  #   @return [String] address country
  # @!attribute state
  #   @return [String] address state
  # @!attribute postal_code
  #   @return [String] address postal code
  #
  class Address < Preneeds::Base
    attribute :street, String
    attribute :street2, String
    attribute :city, String
    attribute :country, String
    attribute :state, String
    attribute :postal_code, String

    # (see Preneeds::BurialForm#as_eoas)
    #
    def as_eoas
      hash = {
        address1: street, address2: street2, city:,
        countryCode: country, postalZip: postal_code, state: state || ''
      }

      hash.delete(:address2) if hash[:address2].blank?
      hash
    end

    # (see Preneeds::Applicant.permitted_params)
    #
    def self.permitted_params
      attribute_set.map { |a| a.name.to_sym }
    end
  end
end
