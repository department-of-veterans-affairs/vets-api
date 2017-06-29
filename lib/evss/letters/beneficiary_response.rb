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
    end
  end
end
