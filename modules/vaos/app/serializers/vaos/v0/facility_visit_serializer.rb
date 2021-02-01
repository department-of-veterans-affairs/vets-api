# frozen_string_literal: true

require 'jsonapi/serializer'

module VAOS
  module V0
    class FacilityVisitSerializer
      include JSONAPI::Serializer

      attributes :has_visited_in_past_months,
                 :duration_in_months
    end
  end
end
