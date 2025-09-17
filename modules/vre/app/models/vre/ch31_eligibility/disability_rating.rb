# frozen_string_literal: true

module VRE
  module Ch31Eligibility
    class DisabilityRating
      include Vets::Model

      attribute :combined_scd, Integer
      attribute :scd_details, ScdDetail, array: true
    end
  end
end
