# frozen_string_literal: true
require 'common/models/base'

module EVSS
  module Letters
    class BenefitInformation < Common::Base
      attribute :has_non_service_connected_pension, Boolean
      attribute :has_service_connected_disabilities, Boolean
      attribute :has_survivors_indemnity_compensation_award, Boolean
      attribute :has_survivors_pension_award, Boolean
      attribute :monthly_award_amount, Float
      attribute :service_connected_percentage, Integer
      attribute :award_effective_date, DateTime

      attribute :has_adapted_housing, Boolean
      attribute :has_chapter35_eligibility, Boolean
      attribute :has_death_result_of_disability, Boolean
      attribute :has_individual_unemployability_granted, Boolean
      attribute :has_special_monthly_compensation, Boolean
    end
  end
end
