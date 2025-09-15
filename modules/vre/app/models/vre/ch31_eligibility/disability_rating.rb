# frozen_string_literal: true

module VRE
  module Ch31Eligibility
    class DisabilityRating
      include Vets::Model

      attribute :combined_scd, Integer
      attribute :service_end_date, String
      attribute :scd_details, ScdDetail, array: true
    end
  end
end
