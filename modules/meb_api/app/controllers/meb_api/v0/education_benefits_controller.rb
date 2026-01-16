# frozen_string_literal: true

require 'dgi/claimant/service'
require 'dgi/letters/service'
require 'dgi/status/service'
require 'dgi/eligibility/service'
require 'dgi/automation/service'
require 'dgi/submission/service'
require 'dgi/enrollment/service'
require 'dgi/contact_info/service'
require 'dgi/exclusion_period/service'

module MebApi
  module V0
    class EducationBenefitsController < MebApi::V0::BaseController
      before_action :set_type, only: %i[claim_letter claim_status claimant_info eligibility]

      def claimant_info
        response = automation_service.get_claimant_info(@form_type)

        render json: AutomationSerializer.new(response)
      end

      def eligibility
        claimant_response = claimant_service.get_claimant_info(@form_type)
        claimant_id = claimant_response.claimant_id

        eligibility_response = eligibility_service.get_eligibility(claimant_id)

        response = claimant_response.status == 201 ? eligibility_response : claimant_response
        serializer = claimant_response.status == 201 ? EligibilitySerializer : ClaimantSerializer

        render json: serializer.new(response)
      end

      def claim_status
        claimant_response = claimant_service.get_claimant_info(@form_type)
        claimant_id = claimant_response.claimant_id

        claim_status_response = claim_status_service.get_claim_status(params, claimant_id, @form_type)

        response = claimant_response.status == 201 ? claim_status_response : claimant_response
        serializer = claimant_response.status == 201 ? ClaimStatusSerializer : ClaimantSerializer

        render json: serializer.new(response)
      end

      def claim_letter
        claimant_response = claimant_service.get_claimant_info(@form_type)
        claimant_id = claimant_response.claimant_id
        claim_status_response = claim_status_service.get_claim_status(params, claimant_id, @form_type)
        claim_letter_response = claim_letters_service.get_claim_letter(claimant_id, @form_type)
        is_eligible = claim_status_response.claim_status == 'ELIGIBLE'
        response = claimant_response.status == 201 ? claim_letter_response : claimant_response

        date = Time.now.getlocal
        timestamp = date.strftime('%m/%d/%Y %I:%M:%S %p')
        filename = is_eligible ? "Post-9/11 GI_Bill_CoE_#{timestamp}" : "Post-9/11 GI_Bill_Denial_#{timestamp}"

        send_data response.body, filename: "#{filename}.pdf", type: 'application/pdf', disposition: 'attachment'

        nil
      end

      def submit_claim
        StatsD.increment('api.meb.submit_claim.attempt')
        response_data = fetch_direct_deposit_info
        response = submission_service.submit_claim(params[:education_benefit].except(:form_id), response_data)

        clear_saved_form(params[:form_id]) if params[:form_id]

        render json: {
          data: {
            status: response.status
          }
        }
      rescue => e
        log_submission_error(e, 'MEB submit_claim failed')
        raise
      end

      def enrollment
        claimant_response = claimant_service.get_claimant_info(@form_type)
        claimant_id = claimant_response.claimant_id
        if claimant_id.nil?
          render json: {
            data: {
              no_911_benefits: true
            }
          }
        else
          response = enrollment_service.get_enrollment(claimant_id)
          render json: EnrollmentSerializer.new(response)
        end
      end

      def send_confirmation_email
        return head :no_content unless Flipper.enabled?(:form1990meb_confirmation_email)

        status = params[:claim_status]
        email = params[:email] || @current_user.email
        first_name = params[:first_name]&.upcase || @current_user.first_name&.upcase

        missing_attributes = []
        missing_attributes << 'claim_status' if status.blank?
        missing_attributes << 'email' if email.blank?
        missing_attributes << 'first_name' if first_name.blank?

        if missing_attributes.any?
          return log_missing_email_attributes('1990meb', missing_attributes, status, email, first_name)
        end

        MebApi::V0::Submit1990mebFormConfirmation.perform_async(status, email, first_name)
      end

      def submit_enrollment_verification
        claimant_response = claimant_service.get_claimant_info(@form_type)
        claimant_id = claimant_response.claimant_id

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
          render json: SubmitEnrollmentSerializer.new(response)
        end
      end

      def duplicate_contact_info
        response = contact_info_service.check_for_duplicates(params[:emails], params[:phones])
        render json: ContactInfoSerializer.new(response)
      end

      def exclusion_periods
        claimant_response = claimant_service.get_claimant_info(@form_type)
        claimant_id = claimant_response.claimant_id
        exclusion_response = exclusion_period_service.get_exclusion_periods(claimant_id)

        render json: ExclusionPeriodSerializer.new(exclusion_response)
      end

      private

      def set_type
        @form_type = params['type']&.capitalize.presence || 'Chapter33'
      end

      def contact_info_service
        MebApi::DGI::ContactInfo::Service.new(@current_user)
      end

      def eligibility_service
        MebApi::DGI::Eligibility::Service.new(@current_user)
      end

      def automation_service
        MebApi::DGI::Automation::Service.new(@current_user)
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

      # Fetch unmasked direct deposit if asterisks present. Gracefully handles failures.
      def fetch_direct_deposit_info
        return nil if Rails.env.development?

        account_number = params.dig(:education_benefit, :direct_deposit, :direct_deposit_account_number)
        routing_number = params.dig(:education_benefit, :direct_deposit, :direct_deposit_routing_number)
        return nil unless account_number&.include?('*') || routing_number&.include?('*')

        DirectDeposit::Client.new(@current_user&.icn).get_payment_info.tap do |response_data|
          if response_data.nil?
            Rails.logger.warn('DirectDeposit::Client returned nil response, proceeding without direct deposit info')
          end
        end
      rescue => e
        Rails.logger.error("Lighthouse direct deposit service error: #{e}")
        nil
      end
    end
  end
end
