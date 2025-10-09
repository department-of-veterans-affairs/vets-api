# frozen_string_literal: true

module VRE
  class Ch31EligibilitySerializer
    include JSONAPI::Serializer

    set_id { '' }

    attributes :veteran_profile,
               :disability_rating,
               :irnd_date,
               :eligibility_termination_date,
               :entitlement_details,
               :res_case_id,
               :qualifying_military_service_status,
               :character_of_discharge_status,
               :disability_rating_status,
               :irnd_status,
               :eligibility_termination_date_status,
               :res_eligibility_recommendation
  end
end
