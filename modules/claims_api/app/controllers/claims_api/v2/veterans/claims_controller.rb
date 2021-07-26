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
          lighthouse_claim = find_lighthouse_claim!(claim_id: params[:id])

          benefit_claim_id = lighthouse_claim.present? ? lighthouse_claim.evss_id : params[:id]
          bgs_claim = find_bgs_claim(claim_id: benefit_claim_id)

          if lighthouse_claim.blank? && bgs_claim.blank?
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
          end

          massaged_bgs_claim = massage_bgs_claim(bgs_claim: bgs_claim)
          lighthouse_claim = lighthouse_claim ? [lighthouse_claim] : []

          claim = BGSToLighthouseClaimsMapperService.process(
            bgs_claims: massaged_bgs_claim,
            lighthouse_claims: lighthouse_claim
          )

          render json: ClaimsApi::V2::Blueprints::ClaimBlueprint.render(claim, base_url: request.base_url)
        end

        private

        def bgs_service
          BGS::Services.new(external_uid: target_veteran.participant_id,
                            external_key: target_veteran.participant_id)
        end

        def find_lighthouse_claim!(claim_id:)
          lighthouse_claim = ClaimsApi::AutoEstablishedClaim.get_by_id_or_evss_id(claim_id)

          if looking_for_lighthouse_claim?(claim_id: claim_id) && lighthouse_claim.blank?
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
          end

          lighthouse_claim
        end

        def find_bgs_claim(claim_id:)
          bgs_service.ebenefits_benefit_claims_status.find_benefit_claim_details_by_benefit_claim_id(
            benefit_claim_id: claim_id
          )
        end

        def looking_for_lighthouse_claim?(claim_id:)
          claim_id.to_s.include?('-')
        end

        def massage_bgs_claim(bgs_claim:)
          {
            benefit_claims_dto: {
              benefit_claim: [
                {
                  benefit_claim_id: bgs_claim[:benefit_claim_details_dto][:benefit_claim_id],
                  claim_status_type: bgs_claim[:benefit_claim_details_dto][:claim_status_type]
                }
              ]
            }
          }
        end
      end
    end
  end
end
