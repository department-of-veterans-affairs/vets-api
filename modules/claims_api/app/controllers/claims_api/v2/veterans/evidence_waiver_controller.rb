# frozen_string_literal: true

module ClaimsApi
  module V2
    module Veterans
      class EvidenceWaiverController < ClaimsApi::V2::ApplicationController
        before_action :verify_access!

        def submit
          bgs_claim = find_bgs_claim!(claim_id: params[:id])

          if bgs_claim&.dig(:bnft_claim_dto).nil?
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
          end

          render json: { success: true }
        end

        private

        def find_bgs_claim!(claim_id:)
          return if claim_id.blank?

          bgs_service.benefit_claims.find_bnft_claim(claim_id: claim_id)
        rescue Savon::SOAPFault => e
          if e.message.include?("For input string: \"#{claim_id}\"") ||
             e.message.include?("No BnftClaim found for #{claim_id}")
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found', status: 404)
          end

          raise
        end
      end
    end
  end
end
