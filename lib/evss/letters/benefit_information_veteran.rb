# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module Letters
    class BenefitInformationVeteran < BenefitInformation
      attribute :has_non_service_connected_pension, Boolean
      attribute :has_service_connected_disabilities, Boolean
      attribute :has_adapted_housing, Boolean
      attribute :has_individual_unemployability_granted, Boolean
      attribute :has_special_monthly_compensation, Boolean
    end
  end
end
