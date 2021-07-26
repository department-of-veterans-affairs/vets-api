# frozen_string_literal: true

module ClaimsApi
  module V2
    module Veterans
      class ClaimsController < ClaimsApi::V2::ApplicationController
        before_action :verify_access!

        def index
          bgs_claims = bgs_service.ebenefits_benefit_claims_status.find_benefit_claims_status_by_ptcpnt_id(
            participant_id: target_veteran.participant_id
          )

          lighthouse_claims = ClaimsApi::AutoEstablishedClaim.where(veteran_icn: target_veteran.mpi.icn)
          merged_claims = BGSToLighthouseClaimsMapperService.process(bgs_claims: bgs_claims,
                                                                     lighthouse_claims: lighthouse_claims)

          render json: ClaimsApi::V2::Blueprints::ClaimBlueprint.render(merged_claims, base_url: request.base_url)
        end

        def show
          lighthouse_claim = ClaimsApi::AutoEstablishedClaim.get_by_id_or_evss_id(params[:id])
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found') if lighthouse_claim.blank? && params[:id].to_s.include?('-')

          benefit_claim_id = lighthouse_claim.present? ? lighthouse_claim.evss_id : params[:id]
          bgs_claim = bgs_service.ebenefits_benefit_claims_status.find_benefit_claim_details_by_benefit_claim_id(benefit_claim_id: benefit_claim_id)

          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found') if lighthouse_claim.blank? && bgs_claim.blank?

          massaged_bgs_claim = {
            benefit_claims_dto: {
              benefit_claim: [
                {
                  benefit_claim_id: bgs_claim[:benefit_claim_details_dto][:benefit_claim_id],
                  claim_status_type: bgs_claim[:benefit_claim_details_dto][:claim_status_type]
                }
              ]
            }
          }
          lighthouse_claim = lighthouse_claim ? [lighthouse_claim] : []

          claim = BGSToLighthouseClaimsMapperService.process(bgs_claims: massaged_bgs_claim, lighthouse_claims: lighthouse_claim)

          render json: ClaimsApi::V2::Blueprints::ClaimBlueprint.render(claim, base_url: request.base_url)
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
