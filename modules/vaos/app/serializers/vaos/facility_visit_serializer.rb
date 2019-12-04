# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  class FacilityVisitSerializer
    include FastJsonapi::ObjectSerializer

    set_id :institution_code
    attributes :has_visited_in_past_monthss,
      :duration_in_months
  end
end
