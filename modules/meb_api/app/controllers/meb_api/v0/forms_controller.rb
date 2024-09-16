# frozen_string_literal: true

require 'dgi/forms/service/sponsor_service'
require 'dgi/forms/service/claimant_service'
require 'dgi/forms/service/submission_service'
require 'dgi/forms/service/letter_service'

module MebApi
  module V0
    class FormsController < MebApi::V0::BaseController
      before_action :check_forms_flipper

      def claim_letter
        claimant_response = claimant_service.get_claimant_info('toe')
        claimant_id = claimant_response['claimant']['claimant_id']
        claim_status_response = claim_status_service.get_claim_status(params, claimant_id, 'toe')
        claim_letter_response = letter_service.get_claim_letter(claimant_id, 'toe')
        is_eligible = claim_status_response.claim_status == 'ELIGIBLE'
        response = claimant_response.status == 200 ? claim_letter_response : claimant_response

        date = Time.now.getlocal
        timestamp = date.strftime('%m/%d/%Y %I:%M:%S %p')
        filename = is_eligible ? "Post-9/11 GI_Bill_CoE_#{timestamp}" : "Post-9/11 GI_Bill_Denial_#{timestamp}"

        send_data response.body, filename: "#{filename}.pdf", type: 'application/pdf', disposition: 'attachment'

        nil
      end

      def claim_status
        claimant_response = claimant_service.get_claimant_info('toe')
        claimant_id = claimant_response['claimant']['claimant_id']

        claim_status_response = claim_status_service.get_claim_status(params, claimant_id, 'toe')

        response = claimant_response.status == 200 ? claim_status_response : claimant_response
        serializer = claimant_response.status == 200 ? ClaimStatusSerializer : ClaimantSerializer

        render json: serializer.new(response)
      end

      def claimant_info
        response = claimant_service.get_claimant_info('toe')

        render json: ToeClaimantInfoSerializer.new(response)
      end

      def sponsors
        response = sponsor_service.post_sponsor

        render json: SponsorsSerializer.new(response)
      end

      def submit_claim
        response_data = nil

        if Flipper.enabled?(:toe_light_house_dgi_direct_deposit, @current_user) && !Rails.env.development?
          begin
            response_data = DirectDeposit::Client.new(@current_user&.icn).get_payment_info
            if response_data.nil?
              Rails.logger.warn('DirectDeposit::Client returned nil response, proceeding without direct deposit info')
            end
          rescue => e
            Rails.logger.error("BIS service error: #{e}")
          end
        end

        response = submission_service.submit_claim(params, response_data, 'toe')

        clear_saved_form(params[:form_id]) if params[:form_id]

        render json: {
          data: {
            'status': response.status
          }
        }
      end

      def send_confirmation_email
        return head :no_content unless Flipper.enabled?(:form1990emeb_confirmation_email)

        status = params[:claim_status]
        email = params[:email] || @current_user.email
        first_name = params[:first_name]&.upcase || @current_user.first_name&.upcase

        MebApi::V0::Submit1990emebFormConfirmation.perform_async(status, email, first_name)
      end

      private

      def claimant_service
        MebApi::DGI::Forms::Claimant::Service.new(@current_user)
      end

      def letter_service
        MebApi::DGI::Forms::Letters::Service.new(@current_user)
      end

      def sponsor_service
        MebApi::DGI::Forms::Sponsor::Service.new(@current_user)
      end

      def submission_service
        MebApi::DGI::Forms::Submission::Service.new(@current_user)
      end
    end
  end
end
