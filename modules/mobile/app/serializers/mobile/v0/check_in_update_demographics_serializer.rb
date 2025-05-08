# frozen_string_literal: true

module Mobile
  module V0
    class CheckInUpdateDemographicsSerializer
      include JSONAPI::Serializer

      set_type :demographicConfirmations
      attributes :contactNeedsUpdate,
                 :emergencyContactNeedsUpdate,
                 :nextOfKinNeedsUpdate
    end
  end
end
