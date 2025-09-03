# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class ClinicalNotes
    include Vets::Model

    attribute :id, String
    attribute :name, String
    attribute :note_type, String
    attribute :loinc_codes, Array
    attribute :date, String
    attribute :date_signed, String
    attribute :written_by, String
    attribute :signed_by, String
    attribute :discharge_date, String
    attribute :location, String
    attribute :note, String
  end
end
