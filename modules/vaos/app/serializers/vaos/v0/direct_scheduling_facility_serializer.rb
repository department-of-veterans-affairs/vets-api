# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'jsonapi/serializer'

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
# :nocov:
