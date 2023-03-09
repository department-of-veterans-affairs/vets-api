# frozen_string_literal: true

module FacilitiesApi
  class V1::PPMS::SpecialtySerializer
    include JSONAPI::Serializer

    set_id :specialty_code
    set_key_transform :camel_lower

    attributes :classification,
               :grouping,
               :name,
               :specialization,
               :specialty_code,
               :specialty_description
  end
end
