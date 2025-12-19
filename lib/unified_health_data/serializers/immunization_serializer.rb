# frozen_string_literal: true

module UnifiedHealthData
  class ImmunizationSerializer
    include JSONAPI::Serializer

    set_id :id
    set_type :immunization

    attributes :cvx_code,
               :date,
               :dose_number,
               :dose_series,
               :group_name,
               :location,
               :location_id,
               :manufacturer,
               :note,
               :reaction,
               :short_description,
               :administration_site,
               :lot_number,
               :status
  end
end
