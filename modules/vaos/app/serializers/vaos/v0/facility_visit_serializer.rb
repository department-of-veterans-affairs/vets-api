# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  module V0
    class FacilityVisitSerializer
      include FastJsonapi::ObjectSerializer

      attributes :has_visited_in_past_months,
                 :duration_in_months
    end
  end
end
