# frozen_string_literal: true
require 'common/client/concerns/service_status'

module EVSS
  module Letters
    class BeneficiaryResponse < EVSS::Response
      attribute :benefit_information, EVSS::Letters::BenefitInformation
      attribute :military_service, Array[EVSS::Letters::MilitaryService]

      def initialize(status, response = nil)
        attributes = response.body if response
        super(status, attributes)
      end

      def benefit_information=(value)
        if value.has_key? 'has_service_connected_disabilities'
          super EVSS::Letters::BenefitInformationVeteran.new(value)
        else
          super EVSS::Letters::BenefitInformationDependent.new(value)
        end
      end
    end
  end
end
