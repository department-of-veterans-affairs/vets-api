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

      def benefit_information=(attrs)
        if veteran_attributes?(attrs)
          super EVSS::Letters::BenefitInformationVeteran.new(attrs)
        else
          super EVSS::Letters::BenefitInformationDependent.new(attrs)
        end
      end

      private

      def veteran_attributes?(attrs)
        attrs.key? 'has_service_connected_disabilities'
      end
    end
  end
end
