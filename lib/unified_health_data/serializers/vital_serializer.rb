# frozen_string_literal: true

module UnifiedHealthData
  class VitalSerializer
    include JSONAPI::Serializer

    set_id :id
    set_type :observation

    attributes :id,
               :name,
               :type,
               :date,
               :measurement,
               :location,
               :notes
  end
end
