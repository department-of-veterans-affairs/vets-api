# frozen_string_literal: true

module VRE
  module Ch31Eligibility
    class VeteranProfile
      include Vets::Model

      attribute :first_name, String
      attribute :last_name, String
      attribute :dob, String
      attribute :character_of_discharge, String
      attribute :service_period, ServicePeriod, array: true
    end
  end
end
