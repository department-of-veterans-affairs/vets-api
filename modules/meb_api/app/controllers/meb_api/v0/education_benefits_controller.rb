# frozen_string_literal: true

require 'dgi/eligibility/service'
require 'dgi/automation/service'
require 'dgi/submission/service'
require 'dgi/enrollment/service'
require 'dgi/contact_info/service'
require 'dgi/exclusion_period/service'
require 'bgs/service'

module MebApi
  module V0
    class EducationBenefitsController < MebApi::V0::BaseController
      def claimant_info
        response = automation_service.get_claimant_info('Chapter33')

        render json: response, serializer: AutomationSerializer
      end

      def eligibility
        claimant_response = claimant_service.get_claimant_info
        claimant_id = claimant_response['claimant_id']

        eligibility_response = eligibility_service.get_eligibility(claimant_id)

        response = claimant_response.status == 201 ? eligibility_response : claimant_response
        serializer = claimant_response.status == 201 ? EligibilitySerializer : ClaimantSerializer

        render json: response, serializer:
      end

      def claim_status
        claimant_response = claimant_service.get_claimant_info
        claimant_id = claimant_response['claimant_id']
        claim_status_response = claim_status_service.get_claim_status(params, claimant_id)

        response = claimant_response.status == 201 ? claim_status_response : claimant_response
        serializer = claimant_response.status == 201 ? ClaimStatusSerializer : ClaimantSerializer

        render json: response, serializer:
      end

      def claim_letter
        claimant_response = claimant_service.get_claimant_info
        claimant_id = claimant_response['claimant_id']
        claim_status_response = claim_status_service.get_claim_status(params, claimant_id)
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
        response_data = nil
        if Flipper.enabled?(:show_dgi_direct_deposit_1990EZ, @current_user) && !Rails.env.development?
          begin
            response_data = payment_service.get_ch33_dd_eft_info
          rescue => e
            Rails.logger.error("BGS service error: #{e}")
            head :internal_server_error
            return
          end
        end

        response = submission_service.submit_claim(params[:education_benefit].except(:form_id), response_data)

        clear_saved_form(params[:form_id]) if params[:form_id]

        send_confirmation_email if response.ok? && Flipper.enabled?(:form1990meb_confirmation_email)

        render json: {
          data: {
            'status': response.status
          }
        }
      end

      def enrollment
        claimant_response = claimant_service.get_claimant_info
        claimant_id = claimant_response['claimant_id']
        if claimant_id.nil?
          render json: {
            data: {
              no_911_benefits: true
            }
          }
        else
          response = enrollment_service.get_enrollment(claimant_id)
          render json: response, serializer: EnrollmentSerializer
        end
      end

      def submit_enrollment_verification
        claimant_response = claimant_service.get_claimant_info
        claimant_id = claimant_response['claimant_id']

        if claimant_id.to_i.zero?
          render json: {
            data: {
              enrollment_certify_responses: []
            }
          }
        else
          response = enrollment_service.submit_enrollment(
            params[:education_benefit], claimant_id
          )
          render json: response, serializer: SubmitEnrollmentSerializer
        end
      end

      def duplicate_contact_info
        response = contact_info_service.check_for_duplicates(params[:emails], params[:phones])
        render json: response, serializer: ContactInfoSerializer
      end

      def exclusion_periods
        claimant_response = claimant_service.get_claimant_info
        claimant_id = claimant_response['claimant_id']
        exclusion_response = exclusion_period_service.get_exclusion_periods(claimant_id)

        render json: exclusion_response, serializer: ExclusionPeriodSerializer
      end

      private

      def contact_info_service
        MebApi::DGI::ContactInfo::Service.new(@current_user)
      end

      def eligibility_service
        MebApi::DGI::Eligibility::Service.new(@current_user)
      end

      def automation_service
        MebApi::DGI::Automation::Service.new(@current_user)
      end

      def payment_service
        BGS::Service.new(@current_user)
      end

      def submission_service
        MebApi::DGI::Submission::Service.new(@current_user)
      end

      def enrollment_service
        MebApi::DGI::Enrollment::Service.new(@current_user)
      end

      def exclusion_period_service
        MebApi::DGI::ExclusionPeriod::Service.new(@current_user)
      end

      def send_confirmation_email
        form_data = params[:education_benefit]
        email = form_data.dig('claimant', 'contact_info', 'email_address')
        first_name = form_data.dig('claimant', 'first_name')&.upcase.presence

        if email.present?
          MebApi::V0::Submit1990mebFormConfirmation.perform_async(
            @current_user.uuid, email, first_name
          )
        end
      end
    end
  end
end
