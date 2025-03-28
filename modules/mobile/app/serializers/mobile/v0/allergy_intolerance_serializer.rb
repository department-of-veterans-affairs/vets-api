# frozen_string_literal: true

module Mobile
  module V0
    class AllergyIntoleranceSerializer
      include JSONAPI::Serializer

      set_type :allergy_intolerance

      attributes :resourceType,
                 :type,
                 :clinicalStatus,
                 :code,
                 :recordedDate,
                 :patient,
                 :notes,
                 :recorder,
                 :reactions,
                 :category
    end
  end
end
