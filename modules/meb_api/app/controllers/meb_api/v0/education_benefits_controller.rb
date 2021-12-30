# frozen_string_literal: true

require 'dgi/eligibility/service'
require 'dgi/automation/service'
require 'dgi/status/service'

module MebApi
  module V0
    class EducationBenefitsController < MebApi::V0::BaseController
      # disabling checks while we serve big mock JSON objects. Check will be reinstated when we integrate with DGIB
      def claimant_info
        response = automation_service.get_claimant_info

        render json: response, serializer: AutomationSerializer
      end

      def eligibility
        response = eligibility_service.get_eligibility

        render json: response, serializer: EligibilitySerializer
      end

      def claim_status
        response = claim_status_service.get_claim_status(params[:claimant_id])
        render json: response, serializer: ClaimStatusSerializer
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

      def claim_status_service
        MebApi::DGI::Status::Service.new(@current_user)
      end
    end
  end
end
