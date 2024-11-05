# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class LetterInfo < Common::Resource
      attribute :id, Types::String
      attribute :benefit_information, BenefitInformation
      attribute :military_service, Types::Array.of(BenefitMilitaryInformation)
    end
  end
end
