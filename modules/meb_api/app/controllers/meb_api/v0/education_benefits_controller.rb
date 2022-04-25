# frozen_string_literal: true

require 'dgi/eligibility/service'
require 'dgi/automation/service'
require 'dgi/status/service'
require 'dgi/submission/service'
require 'dgi/letters/service'
require 'dgi/enrollment/service'
require 'dgi/claimant/service'

module MebApi
  module V0
    class EducationBenefitsController < MebApi::V0::BaseController
      def claimant_info
        response = automation_service.get_claimant_info

        render json: response, serializer: AutomationSerializer
      end

      def eligibility
        claimant_response = claimant_service.get_claimant_info
        claimant_id = claimant_response['claimant_id']

        eligibility_response = eligibility_service.get_eligibility(claimant_id)

        response = claimant_response.status == 201 ? eligibility_response : claimant_response
        serializer = claimant_response.status == 201 ? EligibilitySerializer : ClaimantSerializer

        render json: response, serializer: serializer
      end

      def claim_status
        claimant_response = claimant_service.get_claimant_info
        claimant_id = claimant_response['claimant_id']

        claim_status_response = claim_status_service.get_claim_status(claimant_id)

        response = claimant_response.status == 201 ? claim_status_response : claimant_response
        serializer = claimant_response.status == 201 ? ClaimStatusSerializer : ClaimantSerializer

        render json: response, serializer: serializer
      end

      def claim_letter
        claimant_response = claimant_service.get_claimant_info
        claimant_id = claimant_response['claimant_id']
        claim_status_response = claim_status_service.get_claim_status(claimant_id)
        claim_letter_response = claim_letters_service.get_claim_letter(claimant_id)
        is_eligible = claim_status_response.claim_status == 'ELIGIBLE'
        response = claimant_response.status == 201 ? claim_letter_response : claimant_response

        date = Time.now.getlocal
        timestamp = date.strftime('%m/%d/%Y %I:%M:%S %p')
        filename = is_eligible ? "Post-9/11 GI_Bill_CoE_#{timestamp}" : "Post-9/11 GI_Bill_Denial_#{timestamp}"

        send_data response.body, filename: "#{filename}.pdf", type: 'application/pdf', disposition: 'attachment'

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
        claimant_response = claimant_service.get_claimant_info
        claimant_id = claimant_response['claimant_id']
        response = enrollment_service.get_enrollment(claimant_id)

        render json: response, serializer: EnrollmentSerializer
      end

      def submit_enrollment_verification
        response = enrollment_service.submit_enrollment(params[:enrollment_verifications])

        render json: response, serializer: SubmitEnrollmentSerializer
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

      def claimant_service
        MebApi::DGI::Claimant::Service.new(@current_user)
      end
    end
  end
end
