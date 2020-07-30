# frozen_string_literal: true

class PPMS::SpecialtySerializer
  include FastJsonapi::ObjectSerializer

  set_id :specialty_code

  attributes :classification,
             :grouping,
             :specialization,
             :specialty_code,
             :specialty_description
end
