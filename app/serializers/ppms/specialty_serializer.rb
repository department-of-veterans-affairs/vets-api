# frozen_string_literal: true

class PPMS::SpecialtySerializer
  include JSONAPI::Serializer

  set_id :specialty_code

  attributes :classification,
             :grouping,
             :name,
             :specialization,
             :specialty_code,
             :specialty_description
end
