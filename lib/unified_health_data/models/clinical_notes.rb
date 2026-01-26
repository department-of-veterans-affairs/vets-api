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
    attribute :sort_date, String # Normalized date for sorting (internal use only)
    attribute :date_signed, String
    attribute :written_by, String
    attribute :signed_by, String
    attribute :admission_date, String
    attribute :discharge_date, String
    attribute :location, String
    attribute :note, String

    default_sort_by sort_date: :desc
  end
end
