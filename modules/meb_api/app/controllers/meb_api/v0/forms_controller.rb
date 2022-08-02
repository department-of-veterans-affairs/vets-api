# frozen_string_literal: true

require 'dgi/forms/service/sponsor_service'

module MebApi
  module V0
    class FormsController < MebApi::V0::BaseController
      before_action :check_flipper
      before_action :get_form_type

      def claim_letter
        claimant_response = claimant_service.get_claimant_info(@form_type)
        claimant_id = claimant_response['claimant_id']
        claim_status_response = claim_status_service.get_claim_status(@form_type, claimant_id)
        claim_letter_response = letter_service.get_claim_letter(@form_type, claimant_id)
        is_eligible = claim_status_response.claim_status == 'ELIGIBLE'
        response = claimant_response.status == 201 ? claim_letter_response : claimant_response

        date = Time.now.getlocal
        timestamp = date.strftime('%m/%d/%Y %I:%M:%S %p')
        filename = is_eligible ? "Post-9/11 GI_Bill_CoE_#{timestamp}" : "Post-9/11 GI_Bill_Denial_#{timestamp}"

        send_data response.body, filename: "#{filename}.pdf", type: 'application/pdf', disposition: 'attachment'

        nil
      end

      def sponsor
        response = sponsor_service.post_sponsor(@form_type)

        render json: response, serializer: SponsorsSerializer
      end

      private

      def get_form_type
        @form_type = params[:form_type]
      end

      def claimant_service
        MebApi::DGI::Forms::Service::ClaimantService.new(@current_user)
      end

      def letter_service
        MebApi::DGI::Forms::Service::LetterService.new(@current_user)
      end

      def sponsor_service
        MebApi::DGI::Forms::Service::SponsorService.new(@current_user)
      end

      def submission_service
        MebApi::DGI::Forms::Service::SubmissionService.new(@current_user)
      end
    end
  end
end
