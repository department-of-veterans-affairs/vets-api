# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    module CheckIn
      class Demographics < Common::Resource
        attribute :id, Types::String
        attribute :insuranceVerificationNeeded, Types::Bool
        attribute :needsConfirmation, Types::Bool
        attribute :mailingAddress, Address
        attribute :residentialAddress, Address
        attribute :homePhone, Types::String
        attribute :officePhone, Types::String
        attribute :cellPhone, Types::String
        attribute :email, Types::String
        attribute :emergencyContact, Contact
        attribute :nextOfKin, Contact
      end
    end
  end
end
