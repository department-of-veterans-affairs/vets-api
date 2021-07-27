# frozen_string_literal: true

module ClaimsApi
  module V2
    module Veterans
      class ClaimsController < ClaimsApi::V2::ApplicationController
        before_action :verify_access!

        def index
          bgs_claims = bgs_service.benefit_claims.find_claims_details_by_participant_id(
            participant_id: target_veteran.participant_id
          )
          lighthouse_claims = ClaimsApi::AutoEstablishedClaim.where(veteran_icn: target_veteran.mpi.icn)
          merged_claims = BGSToLighthouseClaimsMapperService.process(bgs_claims: bgs_claims,
                                                                     lighthouse_claims: lighthouse_claims)

<<<<<<< HEAD
          render json: ClaimsApi::V2::Blueprints::ClaimBlueprint.render(merged_claims, base_url: request.base_url)
=======
          render json: ClaimsApi::V2::Blueprints::ClaimBlueprint.render(merged_claims)
>>>>>>> 13f2f6f0249e1e0e1ee9555459e9a53043578919
        end

        def show
          claim = ClaimsApi::AutoEstablishedClaim.get_by_id_or_evss_id(params[:id])

          if claim.present?
            claim_details = { id: params[:id], type: claim[:claim_type] }
          else
            # If we don't have it, it might still be in BGS, so check there
            bgs_claim = bgs_service.benefit_claims.find_claim_details_by_claim_id(claim_id: params[:id])
            claim_details = bgs_claim.dig(:bnft_claim_detail)

            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found') if claim_details.blank?

            claim_details = { id: params[:id], type: claim_details[:bnft_claim_type_nm] }
          end

          render json: ClaimsApi::V2::Blueprints::ClaimBlueprint.render(claim_details, base_url: request.base_url)
        end

        private

        def bgs_service
          BGS::Services.new(external_uid: target_veteran.participant_id,
                            external_key: target_veteran.participant_id)
        end
      end
    end
  end
end
