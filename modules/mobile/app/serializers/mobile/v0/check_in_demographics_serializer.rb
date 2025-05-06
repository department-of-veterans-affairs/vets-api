# frozen_string_literal: true

require 'jsonapi/serializer'

module Mobile
  module V0
    class CheckInDemographicsSerializer
      include JSONAPI::Serializer
      set_type :checkInDemographics

      attributes :insuranceVerificationNeeded,
                 :needsConfirmation,
                 :mailingAddress,
                 :residentialAddress,
                 :homePhone,
                 :officePhone,
                 :cellPhone,
                 :email,
                 :emergencyContact,
                 :nextOfKin
    end
  end
end
