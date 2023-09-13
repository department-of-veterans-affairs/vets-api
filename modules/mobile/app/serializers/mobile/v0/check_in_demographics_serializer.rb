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

      def initialize(user_id, demographics_info)
        resource = CheckInDemographicsStruct.new(id: user_id,
                                                 insuranceVerificationNeeded:
                                                   demographics_info[:insuranceVerificationNeeded],
                                                 needsConfirmation: demographics_info[:needsConfirmation],
                                                 mailingAddress: demographics_info[:mailingAddress],
                                                 residentialAddress: demographics_info[:residentialAddress],
                                                 homePhone: demographics_info[:homePhone],
                                                 officePhone: demographics_info[:officePhone],
                                                 cellPhone: demographics_info[:cellPhone],
                                                 email: demographics_info[:email],
                                                 emergencyContact: demographics_info[:emergencyContact],
                                                 nextOfKin: demographics_info[:nextOfKin])

        super(resource)
      end
    end

    CheckInDemographicsStruct = Struct.new(:id, :insuranceVerificationNeeded,
                                           :needsConfirmation,
                                           :email_address,
                                           :mailingAddress,
                                           :residentialAddress,
                                           :homePhone,
                                           :officePhone,
                                           :cellPhone,
                                           :email,
                                           :emergencyContact,
                                           :nextOfKin)
  end
end
