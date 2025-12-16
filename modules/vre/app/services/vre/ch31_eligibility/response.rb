# frozen_string_literal: true

module VRE
  module Ch31Eligibility
    class Response
      include Vets::Model

      attribute :veteran_profile, VeteranProfile
      attribute :disability_rating, DisabilityRating
      attribute :irnd_date, String
      attribute :eligibility_termination_date, String
      attribute :entitlement_details, EntitlementDetails
      attribute :res_case_id, Integer
      attribute :qualifying_military_service_status, String
      attribute :character_of_discharge_status, String
      attribute :disability_rating_status, String
      attribute :irnd_status, String
      attribute :eligibility_termination_date_status, String
      attribute :res_eligibility_recommendation, String

      def initialize(_status, response = nil)
        super(response.body) if response
      end
    end
  end
end
