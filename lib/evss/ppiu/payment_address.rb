# frozen_string_literal: true

require 'vets/model'

module EVSS
  module PPIU
    ##
    # Model for the user's payment address
    #
    # @!attribute type
    #   @return [String] The address type, i.e. international, domestic, or military
    # @!attribute address_effective_date
    #   @return [DateTime] The date at which the address is known to be valid
    # @!attribute address_one
    #   @return [String] The first line of the address
    # @!attribute address_two
    #   @return [String] The second line of the address
    # @!attribute address_three
    #   @return [String] The third line of the address
    # @!attribute city
    #   @return [String] The name of the city
    # @!attribute state_code
    #   @return [String] Two-character abbreviation for a state, i.e. VA for Virginia
    # @!attribute zip_code
    #   @return [String] The address zip code
    # @!attribute zip_suffix
    #   @return [String] The optional suffix for the zip code
    # @!attribute country_name
    #   @return [String] The name of the country
    # @!attribute military_post_office_type_code
    #   @return [String] For military addresses, the post office type code
    # @!attribute military_state_code
    #   @return [String] For military addresses, the state code
    #
    class PaymentAddress
      include Vets::Model

      attribute :type, String
      attribute :address_effective_date, DateTime
      attribute :address_one, String
      attribute :address_two, String
      attribute :address_three, String
      attribute :city, String
      attribute :state_code, String
      attribute :zip_code, String
      attribute :zip_suffix, String
      attribute :country_name, String
      attribute :military_post_office_type_code, String
      attribute :military_state_code, String
    end
  end
end
