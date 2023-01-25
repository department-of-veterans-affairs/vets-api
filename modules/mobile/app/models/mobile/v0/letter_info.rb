# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class LetterInfo < Common::Resource
      attribute :benefit_information, BenefitInformation
      attribute :military_service, Types::Array
    end
  end
end
