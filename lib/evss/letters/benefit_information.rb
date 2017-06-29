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
    end
  end
end
