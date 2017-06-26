# frozen_string_literal: true
require 'common/client/concerns/service_status'

module EVSS
  module Letters
    class BeneficiaryResponse < EVSS::Response
      attribute :benefit_information, EVSS::Letters::BenefitInformation
      attribute :military_service, Array[EVSS::Letters::MilitaryService]
      attribute :has_adapted_housing, Boolean
      attribute :has_chapter35_eligibility, Boolean
      attribute :has_death_result_of_disability, Boolean
      attribute :has_individual_unemployability_granted, Boolean
      attribute :has_special_monthly_compensation, Boolean

      def initialize(status, response = nil)
        attributes = response.body if response
        super(status, attributes)
      end
    end
  end
end
