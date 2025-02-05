# frozen_string_literal: true

require 'csv'

module Burials
  # assemble the address lines for the nearest processing office
  class ProcessingOffice
    FILE = Rails.root.join(Burials::MODULE_PATH, 'config', 'zip_to_facility.csv')
    MAPPINGS = CSV.read(FILE).to_h
    DEFAULT = 'Milwaukee'

    PO_BOX = {
      'Milwaukee' => 5192,
      'St. Paul' => 5365,
      'Philadelphia' => 5206
    }.freeze

    # office name by zipcode
    def self.for_zip(code)
      MAPPINGS[code.to_s] || DEFAULT
    end

    # full address by zipcode
    def self.address_for(code)
      office = for_zip(code)
      box = PO_BOX[office]
      ["Attention:  #{office} Pension Center", "P.O. Box #{box}", "Janesville, WI 53547-#{box}"]
    end
  end
end
