# frozen_string_literal: true

require 'dgi/eligibility/service'
require 'dgi/automation/service'

module MebApi
  module V0
    class EducationBenefitsController < MebApi::V0::BaseController
      # disabling checks while we serve big mock JSON objects. Check will be reinstated when we integrate with DGIB
      def claimant_info
        response = automation_service.get_claimant_info

        render json: response, serializer: AutomationSerializer
      end

      def service_history
        render json:
        { data: {
          'beginDate': '2010-10-26T18:00:54.302Z',
          'endDate': '2021-10-26T18:00:54.302Z',
          'branchOfService': 'ArmyActiveDuty',
          'trainingPeriods': [
            {
              'beginDate': '2018-10-26T18:00:54.302Z',
              'endDate': '2019-10-26T18:00:54.302Z'
            }
          ],
          'exclusionPeriods': [{ 'beginDate': '2012-10-26T18:00:54.302Z', 'endDate': '2013-10-26T18:00:54.302Z' }],
          'characterOfService': 'Honorable',
          'reasonForSeparation': 'ExpirationTimeOfService'
        } }
      end

      def eligibility
        response = eligibility_service.get_eligibility

        render json: response, serializer: EligibilitySerializer
      end

      def claim_status
        render json:
        { data: {
          'claimId': 0,
          'status': 'InProgress'
        } }
      end

      def submit_claim
        render json:
               { data: {
                 'status': 'received'
               } }
      end

      private

      def eligibility_service
        MebApi::DGI::Eligibility::Service.new @current_user
      end

      def automation_service
        MebApi::DGI::Automation::Service.new(@current_user)
      end
    end
  end
end
