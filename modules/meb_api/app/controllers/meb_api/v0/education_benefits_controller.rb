# frozen_string_literal: true

require 'dgi/eligibility/service'
require 'dgi/automation/service'
require 'dgi/status/service'
require 'dgi/submission/service'
require 'dgi/letters/service'
require 'dgi/enrollment/service'

module MebApi
  module V0
    class EducationBenefitsController < MebApi::V0::BaseController
      def claimant_info
        response = automation_service.get_claimant_info

        render json: response, serializer: AutomationSerializer
      end

      def eligibility
        automation_response = automation_service.get_claimant_info
        claimant_id = automation_response['claimant']['claimant_id']
        eligibility_response = eligibility_service.get_eligibility(claimant_id)

        response = automation_response.status == 201 ? eligibility_response : automation_response
        serializer = automation_response.status == 201 ? EligibilitySerializer : AutomationSerializer

        render json: response, serializer: serializer
      end

      def claim_status
        automation_response = automation_service.get_claimant_info
        claimant_id = automation_response['claimant']['claimant_id']

        claim_status_response = claim_status_service.get_claim_status(claimant_id)

        response = automation_response.status == 201 ? claim_status_response : automation_response
        serializer = automation_response.status == 201 ? ClaimStatusSerializer : AutomationSerializer

        render json: response, serializer: serializer
      end

      def claim_letter
        automation_response = automation_service.get_claimant_info
        claimant_id = automation_response['claimant']['claimant_id']

        claim_letter_response = claim_letters_service.get_claim_letter(claimant_id)

        response = automation_response.status == 201 ? claim_letter_response : automation_response

        send_data response.body, filename: 'testing.pdf', type: 'application/pdf', disposition: 'attachment'
        nil
      end

      def submit_claim
        response = submission_service.submit_claim(params[:education_benefit].except(:form_id))

        clear_saved_form(params[:form_id]) if params[:form_id]

        render json: {
          data: {
            'status': response.status
          }
        }
      end

      def enrollment
        response = enrollment_service.get_enrollment(params[:claimant_id])

        render json: response, serializer: EnrollmentSerializer
      end

      def submit_enrollment_verification
        response = enrollment_service.submit_enrollment(params)

        render json: response, serializer: EnrollmentSerializer
      end

      private

      def eligibility_service
        MebApi::DGI::Eligibility::Service.new(@current_user)
      end

      def automation_service
        MebApi::DGI::Automation::Service.new(@current_user)
      end

      def claim_status_service
        MebApi::DGI::Status::Service.new(@current_user)
      end

      def submission_service
        MebApi::DGI::Submission::Service.new(@current_user)
      end

      def claim_letters_service
        MebApi::DGI::Letters::Service.new(@current_user)
      end

      def enrollment_service
        MebApi::DGI::Enrollment::Service.new(@current_user)
      end
    end
  end
end
