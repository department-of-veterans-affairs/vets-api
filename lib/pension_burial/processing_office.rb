# frozen_string_literal: true

require 'csv'
module PensionBurial
  class ProcessingOffice
    FILE = Rails.root.join('config', 'pension_burial', 'zip_to_facility.csv')
    MAPPINGS = Hash[CSV.read(FILE)]
    DEFAULT = 'Milwaukee'

    PO_BOX = {
      'Milwaukee' => 5192,
      'St. Paul' => 5365,
      'Philadelphia' => 5206

    }.freeze

    def self.for_zip(code)
      MAPPINGS[code.to_s] || DEFAULT
    end

    def self.address_for(code)
      office = for_zip(code)
      box = PO_BOX[office]
      ["Attention:  #{office} Pension Center", "P.O. Box #{box}", "Janesville, WI 53547-#{box}"]
    end
  end
end
