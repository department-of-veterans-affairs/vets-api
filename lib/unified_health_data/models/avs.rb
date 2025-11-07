# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class AfterVisitSummary
    include Vets::Model

    attribute :id, String
    attribute :appt_id, String
    attribute :name, String
    attribute :note_type, String
    attribute :loinc_codes, Array
    attribute :content_type, String
    attribute :binary, String # optional base64 encoded string
  end
end
