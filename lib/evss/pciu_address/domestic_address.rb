# frozen_string_literal: true

require_relative 'address'

module EVSS
  module PCIUAddress
    ##
    # Model for addresses within the United States
    #
    # @!attribute city
    #   @return [String] City name, under 30 characters
    # @!attribute state_code
    #   @return [String] Two-letter state abbreviation, e.g. VA for Virginia
    # @!attribute country_name
    #   @return [String] Country name
    # @!attribute zip_code
    #   @return [String] Zip code (exactly 5 digits)
    # @!attribute zip_suffix
    #   @return [String] Zip code suffix (exactly 4 digits with optional leading dash)
    #
    class DomesticAddress < Address
      attribute :city, String
      attribute :state_code, String
      attribute :country_name, String
      attribute :zip_code, String
      attribute :zip_suffix, String

      validates :city, pciu_address_line: true, presence: true, length: { maximum: 30 }
      validates :state_code, presence: true
      validates :zip_code, presence: true

      validates_format_of :zip_code, with: ZIP_CODE_REGEX
      validates_format_of :zip_suffix, with: ZIP_SUFFIX_REGEX, allow_blank: true
    end
  end
end
