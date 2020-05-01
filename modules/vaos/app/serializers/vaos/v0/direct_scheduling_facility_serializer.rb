# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  module V0
    class DirectSchedulingFacilitySerializer < FacilitySerializer
      set_id :institution_code
      attributes :request_supported,
                 :direct_scheduling_supported,
                 :express_times,
                 :institution_timezone
    end
  end
end
