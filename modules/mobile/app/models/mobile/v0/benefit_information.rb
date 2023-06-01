# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class BenefitInformation < Common::Resource
      attribute :award_effective_date, Types::DateTime
      attribute :has_chapter35_eligibility, Types::Bool
      attribute :monthly_award_amount, Types::Float
      attribute :service_connected_percentage, Types::Integer
      attribute :has_death_result_of_disability, Types::Bool
      attribute :has_survivors_indemnity_compensation_award, Types::Bool
      attribute :has_survivors_pension_award, Types::Bool
      attribute :has_adapted_housing, Types::Bool
      attribute :has_individual_unemployability_granted, Types::Bool
      attribute :has_non_service_connected_pension, Types::Bool
      attribute :has_service_connected_disabilities, Types::Bool
      attribute :has_special_monthly_compensation, Types::Bool
    end
  end
end
