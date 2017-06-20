# frozen_string_literal: true
require 'csv'
module PensionBurial
  class ProcessingOffice
    FILE = Rails.root.join('config', 'pension_burial', 'zip_to_facility.csv')
    MAPPINGS = Hash[CSV.read(FILE)]
    DEFAULT = 'Milwaukee'

    def self.from_zip(code)
      MAPPINGS[code.to_s] || DEFAULT
    end
  end
end
