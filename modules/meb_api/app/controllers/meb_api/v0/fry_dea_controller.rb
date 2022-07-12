# frozen_string_literal: true

require 'dgi/fry_dea/service'

module MebApi
  module V0
    class FryDeaController < MebApi::V0::BaseController
      before_action :check_toe_flipper, only: [:sponsor]

      def sponsors
        render json: {
          data: {
            sponsors: [
              {
                firstName: 'Wilford',
                lastName: 'Brimley',
                sponsorRelationship: 'Spouse',
                dateOfBirth: '09/27/1934'
              }
            ],
            status: 201
          }
        }
      end

      def claim_letter
        claimant_response = claimant_service.get_claimant_info('fry')
        claimant_id = claimant_response['claimant_id']
        claim_status_response = claim_status_service.get_claim_status(claimant_id, 'fry')
        claim_letter_response = claim_letters_service.get_claim_letter(claimant_id, 'fry')
        is_eligible = claim_status_response.claim_status == 'ELIGIBLE'
        response = claimant_response.status == 201 ? claim_letter_response : claimant_response

        date = Time.now.getlocal
        timestamp = date.strftime('%m/%d/%Y %I:%M:%S %p')
        filename = is_eligible ? "Post-9/11 GI_Bill_CoE_#{timestamp}" : "Post-9/11 GI_Bill_Denial_#{timestamp}"

        send_data response.body, filename: "#{filename}.pdf", type: 'application/pdf', disposition: 'attachment'

        nil
      end

      private

      def fry_dea_service
        MebApi::DGI::FryDea::Service.new(@current_user)
      end
    end
  end
end
