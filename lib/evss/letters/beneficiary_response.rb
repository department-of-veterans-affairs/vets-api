# frozen_string_literal: true
require 'common/client/concerns/service_status'
require 'common/models/base'

module EVSS
  module Letters
    class BeneficiaryResponse < Common::Base
      include Common::Client::ServiceStatus

      attribute :status, Integer
      attribute :benefit_information, EVSS::Letters::BenefitInformation
      attribute :military_service, Array[EVSS::Letters::MilitaryService]
      attribute :has_adapted_housing, Boolean
      attribute :has_chapter35_eligibility, Boolean
      attribute :has_death_result_of_disability, Boolean
      attribute :has_individual_unemployability_granted, Boolean
      attribute :has_special_monthly_compensation, Boolean

      def initialize(raw_response)
        attrs = raw_response.body
        attrs['status'] = raw_response.status
        super(attrs)
      end

      def ok?
        status == 200
      end

      def metadata
        {
          status: ok? ? RESPONSE_STATUS[:ok] : RESPONSE_STATUS[:server_error]
        }
      end
    end
  end
end
