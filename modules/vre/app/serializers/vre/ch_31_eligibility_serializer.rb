# frozen_string_literal

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
               :res_eligibility_recommendation

  end
end