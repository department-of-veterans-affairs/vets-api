# frozen_string_literal: true

require 'dgi/forms/service/sponsor_service'
require 'dgi/forms/service/claimant_service'
require 'dgi/forms/service/submission_service'

module MebApi
  module V0
    class FormsController < MebApi::V0::BaseController
      before_action :check_forms_flipper

      def claim_letter
        claimant_response = claimant_service.get_claimant_info('toe')
        claimant_id = claimant_response['claimant']['claimant_id']
        claim_status_response = claim_status_service.get_claim_status('toe', claimant_id)
        claim_letter_response = letter_service.get_claim_letter('toe', claimant_id)
        is_eligible = claim_status_response.claim_status == 'ELIGIBLE'
        response = claimant_response.status == 201 ? claim_letter_response : claimant_response

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

        render json: response, serializer:
      end

      def claimant_info
        response = claimant_service.get_claimant_info('toe')

        render json: response, serializer: ToeClaimantInfoSerializer
      end

      def sponsors
        response = sponsor_service.post_sponsor

        render json: response, serializer: SponsorsSerializer
      end

      def submit_claim
        dd_response = nil
        if Flipper.enabled?(:toe_short_circuit_bgs_failure, @current_user)
          begin
            dd_response = payment_service.get_ch33_dd_eft_info
          rescue => e
            Rails.logger.error('BDN service error: ', e)
            head :internal_server_error
            return
          end
        else
          dd_response = payment_service.get_ch33_dd_eft_info
        end

        response = submission_service.submit_claim(params, dd_response, 'toe')

        clear_saved_form(params[:form_id]) if params[:form_id]

        render json: {
          data: {
            'status': response.status
          }
        }
      end

      private

      def claimant_service
        MebApi::DGI::Forms::Claimant::Service.new(@current_user)
      end

      def letter_service
        MebApi::DGI::Forms::Letter::Service.new(@current_user)
      end

      def sponsor_service
        MebApi::DGI::Forms::Sponsor::Service.new(@current_user)
      end

      def submission_service
        MebApi::DGI::Forms::Submission::Service.new(@current_user)
      end

      def payment_service
        BGS::Service.new(@current_user)
      end
    end
  end
end
