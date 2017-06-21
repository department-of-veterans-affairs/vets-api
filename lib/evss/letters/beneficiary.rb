# frozen_string_literal: true
require 'common/models/base'

module EVSS
  module Letters
    class Beneficiary < Common::Base
      attribute :benefit_information, EVSS::Letters::BenefitInformation
      attribute :military_service, Array[EVSS::Letters::MilitaryService]
      attribute :has_adapted_housing, Boolean
      attribute :has_chapter35_eligibility, Boolean
      attribute :has_death_result_of_disability, Boolean
      attribute :has_individual_unemployability_granted, Boolean
      attribute :has_special_monthly_compensation, Boolean
    end
  end
end
