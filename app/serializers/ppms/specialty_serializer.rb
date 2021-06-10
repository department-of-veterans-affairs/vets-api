# frozen_string_literal: true

class PPMS::SpecialtySerializer
  include FastJsonapi::ObjectSerializer

  set_id :specialty_code
  set_key_transform :camel_lower

  attributes :classification,
             :grouping,
             :name,
             :specialization,
             :specialty_code,
             :specialty_description
end
