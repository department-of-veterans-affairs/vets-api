# frozen_string_literal: true

module UnifiedHealthData
  class ClinicalNotesSerializer
    include JSONAPI::Serializer

    set_id :id
    set_type :clinical_note

    attributes :id,
               :name,
               :note_type, # TODO: rename type to note_type
               :loinc_codes,
               :date,
               :date_signed,
               :written_by,
               :signed_by,
               :discharge_date,
               :location,
               :note # base64 encoded
  end
end
