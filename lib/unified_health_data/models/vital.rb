# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class ValueQuantity
    include Vets::Model

    attribute :type, String # e.g. "Diastolic" or "Height"
    attribute :code, String # e.g. "mm[Hg]"
    attribute :value, Float # e.g. 120.0
    attribute :unit, String # e.g. "mmHg"
  end

  class Vital
    include Vets::Model

    attribute :id, String
    attribute :name, String
    attribute :type, String # based on LOINC code
    attribute :date, String
    attribute :measurement, String
    attribute :location, String
    attribute :notes, String, array: true
  end
end
