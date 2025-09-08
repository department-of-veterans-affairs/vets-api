# frozen_string_literal: true

module Mobile
  module V1
    class PrescriptionsRefillsSerializer < Mobile::V0::PrescriptionsRefillsSerializer
      # Inherit all behavior from v0 for API compatibility
      # This serializer will work with the transformed UHD refill response
      
      set_type :PrescriptionRefills
    end
  end
end
