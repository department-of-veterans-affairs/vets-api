# frozen_string_literal: true

require_relative 'address'

module EVSS
  module PCIUAddress
    ##
    # Model for addresses outside the United States
    #
    # @!attribute city
    #   @return [String] City name, under 30 characters
    # @!attribute country_name
    #   @return [String] Country name
    #
    class InternationalAddress < Address
      attribute :city, String
      attribute :country_name, String

      validates :city, pciu_address_line: true, presence: true, length: { maximum: 30 }
      validates :country_name, presence: true
    end
  end
end
