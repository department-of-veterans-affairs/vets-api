# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module Letters
    class BenefitInformationDependent < BenefitInformation
      attribute :has_survivors_pension_award, Boolean
      attribute :has_survivors_indemnity_compensation_award, Boolean
      attribute :has_death_result_of_disability, Boolean
    end
  end
end
