# frozen_string_literal: true

module UnifiedHealthData
  class ClinicalNotesSerializer
    include JSONAPI::Serializer

    set_id :id
    set_type :clinical_note

    attributes :id,
               :name,
               :type,
               :date,
               :date_signed,
               :written_by,
               :signed_by,
               :location,
               :note # base64 encoded
  end
end
