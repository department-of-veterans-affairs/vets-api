# frozen_string_literal: true

require 'csv'

module Burials
  # Handles processing office assignment based on zip codes
  # - assemble the address lines for the nearest processing office
  class ProcessingOffice
    # Path to the CSV file containing zip code to facility mappings
    FILE = Rails.root.join(Burials::MODULE_PATH, 'config', 'zip_to_facility.csv')
    # Mapping of zip codes to processing office names from CSV
    MAPPINGS = CSV.read(FILE).to_h
    # Default processing office
    DEFAULT = 'Milwaukee'

    # PO Box numbers for each processing office
    PO_BOX = {
      'Milwaukee' => 5192,
      'St. Paul' => 5365,
      'Philadelphia' => 5206
    }.freeze

    ##
    # Retrieves the processing office for a given zip code
    #
    # @param code [String, Integer] the zip code to look up
    #
    # @return [String] the name of the processing office
    def self.for_zip(code)
      MAPPINGS[code.to_s] || DEFAULT
    end

    ##
    # Returns the mailing address for a given zip code's processing office
    #
    # @param code [String, Integer] the zip code to look up
    #
    # @return [Array<String>] an array of address lines
    def self.address_for(code)
      office = for_zip(code)
      box = PO_BOX[office]
      ["Attention:  #{office} Pension Center", "P.O. Box #{box}", "Janesville, WI 53547-#{box}"]
    end
  end
end
