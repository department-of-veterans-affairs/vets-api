# frozen_string_literal: true

module VRE
  module Ch31Eligibility
    class ServicePeriod
      include Vets::Model

      attribute :service_began_date, String
      attribute :service_end_date, String
      attribute :character_of_discharge, String
    end
  end
end
